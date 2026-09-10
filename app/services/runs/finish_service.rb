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
        @run.update!(run_attributes)
        finish_experiment
      end
      @run
    end

    private

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

    def finish_experiment
      experiment = @run.experiment
      return if experiment.runs.where.not(status: Run::TERMINAL_STATUSES).exists?

      experiment.finished!
    end
  end
end
