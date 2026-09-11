# frozen_string_literal: true

module Runs
  # Reads a terminal run's stored samples the way the engine's `TransitionTracker` read
  # them live (`engine/crates/life-engine/src/metrics.rs`): the transition epoch is the
  # first sample Lab::TransitionRule accepts, once it has been followed by `hold_samples`
  # further samples it also accepts. A sample the rule rejects drops the candidate, and
  # the first candidate to settle is the answer.
  #
  # It exists for runs measured before the tracker survived a snapshot resume: those runs
  # reported a later epoch, or none, while their samples hold the real drop. Live runs are
  # not its business — the runner posts the value with the samples.
  class TransitionEpochService
    include Callable

    HOLD_SAMPLES = Lab::TransitionRule::HOLD_SAMPLES

    def initialize(run:)
      @run = run
    end

    def call
      candidate = nil
      held = 0

      @run.samples.order(:epoch).pluck(:epoch, :values).each do |epoch, values|
        if Lab::TransitionRule.qualifies?(values)
          if candidate.nil?
            candidate = epoch
            held = 0
          else
            held += 1
            return candidate if held >= HOLD_SAMPLES
          end
        else
          candidate = nil
          held = 0
        end
      end

      nil
    end
  end
end
