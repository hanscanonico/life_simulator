# frozen_string_literal: true

module Runs
  # Reads a terminal run's stored samples the way the engine's `TransitionTracker` read
  # them live (`engine/crates/life-engine/src/metrics.rs`): the transition epoch is the
  # first sample whose `compress_ratio` is below the engine's threshold, once it has been
  # followed by `hold_samples` further samples that all stay below it. A sample back above
  # the threshold drops the candidate, and the first candidate to settle is the answer.
  #
  # The engine also disqualifies a sample whose alphabet has collapsed — `op_density`
  # above `max_op_density`, or fewer than `min_alphabet_size` byte values left. Samples
  # recorded before that observable existed carry no `alphabet_size`, so only the
  # `op_density` half of the guard applies here; a sample that carries one is read in
  # full.
  #
  # It exists for runs measured before the tracker survived a snapshot resume: those runs
  # reported a later epoch, or none, while their samples hold the real drop. Live runs are
  # not its business — the runner posts the value with the samples.
  class TransitionEpochService
    include Callable

    THRESHOLD = Lab::Schema.transition.fetch("threshold")
    HOLD_SAMPLES = Lab::Schema.transition.fetch("hold_samples")
    MAX_OP_DENSITY = Lab::Schema.transition.fetch("max_op_density")
    MIN_ALPHABET_SIZE = Lab::Schema.transition.fetch("min_alphabet_size")

    def initialize(run:)
      @run = run
    end

    def call
      candidate = nil
      held = 0

      @run.samples.order(:epoch).pluck(:epoch, :values).each do |epoch, values|
        if qualifies?(values)
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

    private

    def qualifies?(values)
      ratio = values["compress_ratio"]

      ratio.present? && ratio < THRESHOLD && !collapsed?(values)
    end

    # The alphabet guard, read off whatever the sample carries: `op_density` has always
    # been recorded, `alphabet_size` only since the observable was added.
    def collapsed?(values)
      density = values["op_density"]
      alphabet = values["alphabet_size"]

      (density.present? && density > MAX_OP_DENSITY) ||
        (alphabet.present? && alphabet < MIN_ALPHABET_SIZE)
    end
  end
end
