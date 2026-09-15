# frozen_string_literal: true

module Experiments
  # Moves an experiment up or down the queue. The priority lives on the experiment for the
  # runs it has yet to build and on each of its unfinished runs for `Runs::ClaimService`'s
  # `priority desc, id asc` order. A claimed or running run is moved too: when its runner
  # dies and `Runs::ReleaseStaleService` returns it to the queue, it has to come back at
  # the priority the lab asked for, not at the one it was built with.
  class SetPriorityService
    include Callable

    def initialize(experiment:, priority:)
      @experiment = experiment
      @priority = priority
    end

    def call
      Experiment.transaction do
        @experiment.update!(priority: @priority)
        moved = @experiment.runs.where.not(status: Run::TERMINAL_STATUSES).to_a
        moved.each { |run| run.update!(priority: @priority) }
        moved.size
      end
    end
  end
end
