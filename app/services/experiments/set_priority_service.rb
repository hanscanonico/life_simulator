# frozen_string_literal: true

module Experiments
  # Moves an experiment up or down the queue. The priority lives on the experiment for the
  # runs it has yet to build and on each pending run for `Runs::ClaimService`'s
  # `priority desc, id asc` order; runs already claimed or terminal keep theirs.
  class SetPriorityService
    include Callable

    def initialize(experiment:, priority:)
      @experiment = experiment
      @priority = priority
    end

    def call
      Experiment.transaction do
        @experiment.update!(priority: @priority)
        moved = @experiment.runs.pending.to_a
        moved.each { |run| run.update!(priority: @priority) }
        moved.size
      end
    end
  end
end
