# frozen_string_literal: true

module Runs
  # Removes the pending runs of an experiment that sit on an arm its grid no longer has —
  # the radius-64 runs left queued after the axis moved to the well-mixed 0 — so the queue
  # never serves a run the engine would reject. Matching reads the run's canonical params,
  # which is how an arm a run inherited from the engine's defaults matches too.
  class DiscardPendingService
    include Callable
    include DiscardsPendingRuns

    def initialize(experiment:, param:, value:)
      @experiment = experiment
      @param = param
      @value = value
    end

    def call
      raise ArgumentError, "the engine schema has no #{@param} run parameter" unless run_param?

      Run.transaction { discard!(matching_runs) }
    end

    private

    def run_param?
      Lab::Schema.run_defaults.key?(@param.to_s)
    end

    def matching_runs
      @experiment.runs.pending.order(:id).select do |run|
        Lab::CanonicalParams.same_value?(Lab::CanonicalParams.resolve(run.params)[@param.to_s], @value)
      end
    end
  end
end
