# frozen_string_literal: true

module Api
  class RunsController < BaseController
    before_action :set_run, except: :claim
    before_action :authorize_runner!, except: :claim

    def claim
      run = Runs::ClaimService.call(runner_id: runner_id)
      return head :no_content if run.nil?

      render json: run.slice(:id, :params, :seed, :epochs, :epochs_done)
    end

    # The runner's heartbeat thread can have a request in flight when `finish` posts, so a
    # heartbeat that lands after the end must not resurrect the run — and progress only ever
    # moves forward, whatever a delayed heartbeat reports.
    def heartbeat
      return head :no_content if @run.terminal?

      @run.update!(status: "running", heartbeat_at: Time.current,
                   epochs_done: [@run.epochs_done, params.fetch(:epochs_done).to_i].max,
                   started_at: @run.started_at || Time.current)
      head :no_content
    end

    def samples
      Runs::RecordSamplesService.call(run: @run, samples: body_params.fetch("samples", []),
                                      transition_epoch: params[:transition_epoch])
      head :no_content
    end

    def snapshots
      snapshot = @run.snapshots.find_or_initialize_by(epoch: params.fetch(:epoch))
      snapshot.update!(blob: binary(params[:blob]), png: binary(params[:png]))
      head :no_content
    end

    # Where a resumed run picks up: the newest world the runner posted for this run.
    # Only the blob and its epoch travel — the runner restores world bytes and never the
    # PNG, which would double a large world's already multi-megabyte answer.
    def latest_snapshot
      snapshot = @run.snapshots.restorable.order(epoch: :desc).select(:id, :epoch, :blob).first
      return head :no_content if snapshot.nil?

      render json: { epoch: snapshot.epoch, blob: Base64.strict_encode64(snapshot.blob) }
    end

    def finish
      Runs::FinishService.call(run: @run, transition_epoch: params[:transition_epoch],
                               summary: body_params["summary"], error: params[:error])
      head :no_content
    end

    private

    def set_run
      @run = Run.find(params.fetch(:id))
    end

    def authorize_runner!
      return if @run.claimed_by?(runner_id)

      render json: { error: "run is not claimed by #{runner_id}" }, status: :conflict
    end

    def runner_id = params.require(:runner_id)

    def binary(value)
      return nil if value.blank?

      value.respond_to?(:read) ? value.read : Base64.decode64(value)
    end
  end
end
