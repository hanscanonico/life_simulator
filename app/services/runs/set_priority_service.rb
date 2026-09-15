# frozen_string_literal: true

module Runs
  # Moves a single run up or down the queue, for the seed that matters rather than the whole
  # experiment `Experiments::SetPriorityService` carries. A claimed or running run is moved
  # too: when its runner dies and `Runs::ReleaseStaleService` returns it to the queue, it has
  # to come back at the priority the lab asked for. Returns the priority it left behind.
  class SetPriorityService
    include Callable

    def initialize(run:, priority:)
      @run = run
      @priority = priority
    end

    def call
      if @run.terminal?
        raise ArgumentError,
              "Run #{@run.id} is #{@run.status}; only a pending, claimed or running run can be reprioritised."
      end

      previous = @run.priority
      @run.update!(priority: @priority)
      previous
    end
  end
end
