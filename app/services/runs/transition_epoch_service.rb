# frozen_string_literal: true

module Runs
  # Reads a terminal run's stored samples the way the engine's `TransitionTracker` read
  # them live (`engine/crates/life-engine/src/metrics.rs`): the transition epoch is the
  # first crossing CrossingsService reads out of them, the tracker keeping no other.
  #
  # It exists for runs measured before the tracker survived a snapshot resume: those runs
  # reported a later epoch, or none, while their samples hold the real drop. Live runs are
  # not its business — the runner posts the value with the samples.
  class TransitionEpochService
    include Callable

    def initialize(run:)
      @run = run
    end

    def call
      CrossingsService.call(samples: @run.samples.order(:epoch).pluck(:epoch, :values)).first
    end
  end
end
