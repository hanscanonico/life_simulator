# frozen_string_literal: true

module Runs
  # Removes the duplicate runs an earlier, non-idempotent seeding left in an experiment:
  # for every (canonical params, seed) held by more than one run, the survivor is the
  # lowest-id run that is not pending — the one that may already carry a measurement — or
  # the lowest id when all of them are pending. Only pending duplicates are deleted.
  class DiscardDuplicatesService
    include Callable
    include DiscardsPendingRuns

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Run.transaction { discard!(duplicates) }
    end

    private

    def duplicates
      @experiment.runs.order(:id)
                 .group_by { |run| [Lab::CanonicalParams.for(run.params), run.seed] }
                 .each_value.flat_map { |runs| runs.size > 1 ? redundant(runs) : [] }
    end

    def redundant(runs)
      survivor = runs.find { |run| !run.pending? } || runs.first
      (runs - [survivor]).select(&:pending?)
    end
  end
end
