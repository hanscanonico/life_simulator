# frozen_string_literal: true

module Api
  class RunsController < BaseController
    BINARY_TYPE = "application/octet-stream"
    # The epoch a binary answer resumes from; the JSON answer carries it in the body.
    SNAPSHOT_EPOCH_HEADER = "X-Snapshot-Epoch"

    before_action :set_run, except: :claim
    before_action :authorize_runner!, except: %i[claim world]

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
    # PNG, which would double a large world's already multi-megabyte answer. A runner
    # that accepts octet-stream gets the bytes themselves, which spares it the base64
    # expansion and the copies of it that resuming twelve slots at once cannot afford.
    def latest_snapshot
      snapshot = @run.snapshots.restorable.order(epoch: :desc).select(:id, :epoch, :blob).first
      return head :no_content if snapshot.nil?

      if binary_wanted?
        response.set_header(SNAPSHOT_EPOCH_HEADER, snapshot.epoch.to_s)
        send_data snapshot.blob, type: BINARY_TYPE
      else
        render json: { epoch: snapshot.epoch, blob: Base64.strict_encode64(snapshot.blob) }
      end
    end

    # What `runner rescore` re-reads: a stored world of the run, with the params that
    # describe its bytes. Read-only, and deliberately not claim-gated — a rescore measures
    # finished runs, which no runner holds.
    def world
      snapshot = stored_snapshot
      return head :no_content if snapshot.nil?

      render json: { id: @run.id, params: @run.params, seed: @run.seed, epoch: snapshot.epoch,
                     blob: Base64.strict_encode64(snapshot.blob) }
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

    def stored_snapshot
      snapshots = @run.snapshots.restorable.select(:id, :epoch, :blob)
      return snapshots.order(epoch: :desc).first if params[:epoch].blank?

      snapshots.find_by(epoch: params[:epoch])
    end

    def authorize_runner!
      return if @run.claimed_by?(runner_id)

      render json: { error: "run is not claimed by #{runner_id}" }, status: :conflict
    end

    def runner_id = params.require(:runner_id)

    def binary_wanted? = request.accepts.any? { |type| type == BINARY_TYPE }

    def binary(value)
      return nil if value.blank?

      value.respond_to?(:read) ? value.read : Base64.decode64(value)
    end
  end
end
