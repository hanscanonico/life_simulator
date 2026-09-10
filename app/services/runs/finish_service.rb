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
      attributes[:summary] = @summary if @summary.present?
      attributes[:transition_epoch] = @transition_epoch unless @transition_epoch.nil?
      attributes
    end

    def finish_experiment
      experiment = @run.experiment
      return if experiment.runs.where.not(status: Run::TERMINAL_STATUSES).exists?

      experiment.finished!
    end
  end
end
