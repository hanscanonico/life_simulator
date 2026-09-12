# frozen_string_literal: true

module Runs
  # Closes a run and, once no run of the experiment is still outstanding, the experiment.
  class FinishService
    include Callable

    def initialize(run:, transition_epoch: nil, summary: nil, error: nil)
      @run = run
      @transition_epoch = transition_epoch
      @summary = summary
      @error = error
    end

    def call
      Run.transaction do
        @run.assign_attributes(run_attributes)
        @run.persistence = persistence_summary
        @run.save!
        finish_experiment
      end
      log_outcome
      @run
    end

    private

    def log_outcome
      Rails.logger.info("event=run_finished run_id=#{@run.id} experiment=#{experiment.slug} " \
                        "status=#{@run.status} epochs_done=#{@run.epochs_done}")
      return if @error.blank?

      Rails.logger.warn("event=run_failed run_id=#{@run.id} experiment=#{experiment.slug} " \
                        "error=#{@error.to_s.truncate(200).inspect}")
    end

    def experiment = @experiment ||= @run.experiment

    def run_attributes
      attributes = { status: @error.present? ? "failed" : "finished", finished_at: Time.current,
                     error: @error.presence }
      # A finished run burned its whole budget: the last heartbeat is always a little
      # behind the end, and a run reported as 19,342 of 20,000 reads as incomplete.
      attributes[:epochs_done] = @run.epochs if @error.blank?
      attributes[:summary] = @summary if @summary.present?
      attributes[:transition_epoch] = @transition_epoch if @run.earlier_transition_epoch?(@transition_epoch)
      attributes
    end

    # Read off the samples already stored, against the transition epoch this finish has
    # just settled — the run page and the sweep page read the stored value, never the
    # series.
    def persistence_summary = PersistenceSummaryService.call(run: @run).to_h

    def finish_experiment
      return if experiment.runs.where.not(status: Run::TERMINAL_STATUSES).exists?

      experiment.finished!
    end
  end
end
