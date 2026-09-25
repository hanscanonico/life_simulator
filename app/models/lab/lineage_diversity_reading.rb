# frozen_string_literal: true

module Lab
  # The numbers the lineage-diversity sweep was pre-registered with (`docs/design_record.md`,
  # 2026-09-25, "Lineage diversity after a transition"), so the entry and the reading that
  # will apply it name one set of values.
  module LineageDiversityReading
    # Emergence is the record's confirmed `emergence_epoch`, and the run must also read at
    # least this share of orientation-aware replicators at some sample after it: the census
    # that confirms a crossing is blind to reverse copiers (#245).
    SHARE_KEY = "replicator_share"
    MIN_SHARE = 0.5

    # Per emerged run, the median of DIVERSITY_KEY over the last decile of its samples from
    # `emergence_epoch` on: polyphyletic at POLYPHYLETIC and above, monophyletic below
    # MONOPHYLETIC, between otherwise. Fewer than MIN_DECILE_SAMPLES samples in that decile
    # leaves the run unmeasured.
    DIVERSITY_KEY = "lineage_effective_count"
    POLYPHYLETIC = 2.0
    MONOPHYLETIC = 1.5
    MIN_DECILE_SAMPLES = 10

    # An arm with fewer measured emerged runs than this is unread. The trend test and the
    # refutation both need at least MIN_READ_ARMS read arms.
    MIN_ARM_RUNS = 2
    MIN_READ_ARMS = 2

    # The trend: a one-sided Jonckheere–Terpstra test of the last-decile medians across the
    # arms in the order the hypothesis predicts them to rise — well-mixed, then reach
    # shrinking to radius 1 — read at p below TREND_LEVEL. Its p is a permutation p, (1 + b)
    # / (1 + PERMUTATIONS) over dealings drawn from `Random.new(PERMUTATION_SEED)`; the
    # normal approximation is anti-conservative at the arm sizes the sweep expects.
    RADIUS_ORDER = [0, 4, 2, 1].freeze
    TREND_LEVEL = 0.05
    PERMUTATIONS = 100_000
    PERMUTATION_SEED = 20_260_925

    # Secondary and descriptive only.
    DESCRIPTIVE_KEYS = %w[
      lineages_over_one_percent lineage_variation_oriented conserved_core_bytes_oriented
      conserved_core_ops_oriented copy_latency
    ].freeze

    VERDICTS = %i[polyphyletic between monophyletic unmeasured].freeze
    RUN_COLUMNS = %w[radius seed run_id status emerged class last_decile_effective_count emergence_epoch].freeze
    ARM_COLUMNS = %w[
      arm runs finished emerged measured polyphyletic between monophyletic unmeasured median_effective_count reading
      lineages_over_one_percent lineage_variation_oriented conserved_core_bytes_oriented conserved_core_ops_oriented
      copy_latency_last copy_latency_first radius_sweep_emerged radius_sweep_finished
    ].freeze
  end
end
