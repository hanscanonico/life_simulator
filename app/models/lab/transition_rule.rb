# frozen_string_literal: true

module Lab
  # The engine's transition rule (`TransitionTracker`,
  # `engine/crates/life-engine/src/metrics.rs`) as it applies to one stored sample: the
  # world counts as transitioned while `compress_ratio` sits below the threshold and its
  # alphabet has not collapsed. The engine stays the authority — the numbers come from its
  # schema — and every Rails reading of a stored series asks here rather than spelling the
  # comparison out again.
  #
  # `alphabet_size` was added after the earliest runs were measured, so a sample that
  # carries none is read on the `op_density` half of the guard alone.
  #
  # `qualifies_relative?` is the companion rule of the same tracker: the threshold is a
  # fraction of the run's own baseline rather than a constant, the collapse guard is the
  # same one (`docs/design_record.md`, 2026-09-19).
  module TransitionRule
    THRESHOLD = Schema.transition.fetch("threshold")
    HOLD_SAMPLES = Schema.transition.fetch("hold_samples")
    MAX_OP_DENSITY = Schema.transition.fetch("max_op_density")
    MIN_ALPHABET_SIZE = Schema.transition.fetch("min_alphabet_size")
    RELATIVE_FRACTION = Schema.transition.fetch("relative_fraction")
    BASELINE_EPOCHS = Schema.transition.fetch("baseline_epochs")

    module_function

    def qualifies?(values)
      ratio = values["compress_ratio"]

      ratio.present? && ratio < THRESHOLD && !collapsed?(values)
    end

    # At or below the fraction, where the constant rule reads strictly below its
    # threshold: the relative threshold is a measured quantity, not a round number.
    def qualifies_relative?(values, baseline:)
      ratio = values["compress_ratio"]

      ratio.present? && ratio <= RELATIVE_FRACTION * baseline && !collapsed?(values)
    end

    def collapsed?(values)
      density = values["op_density"]
      alphabet = values["alphabet_size"]

      (density.present? && density > MAX_OP_DENSITY) ||
        (alphabet.present? && alphabet < MIN_ALPHABET_SIZE)
    end
  end
end
