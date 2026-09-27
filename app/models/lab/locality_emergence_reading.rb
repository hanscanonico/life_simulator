# frozen_string_literal: true

module Lab
  # The numbers the locality-emergence sweep was pre-registered with (`docs/design_record.md`,
  # 2026-09-27, "Does emergence peak at an intermediate reach?"), so the entry and the reading
  # that applies it name one set of values.
  module LocalityEmergenceReading
    # Emergence is sweep 12's: the record's confirmed `emergence_epoch`, and at least this
    # share of orientation-aware replicators at some sample at or after it.
    SHARE_KEY = LineageDiversityReading::SHARE_KEY
    MIN_SHARE = LineageDiversityReading::MIN_SHARE

    # The arms, finite reach rising and well-mixed last.
    RADIUS_ORDER = [1, 2, 3, 4, 6, 8, 0].freeze
    WELL_MIXED = 0

    # H-peak: radius PEAK_RADIUS emerges more often than each of PEAK_RIVALS, two one-sided
    # Fisher exact tests on emerged of finished, Holm-corrected at family level FAMILY_ALPHA.
    PEAK_RADIUS = 4
    PEAK_RIVALS = [1, WELL_MIXED].freeze
    FAMILY_ALPHA = 0.05

    # H-shape: a logistic regression of emergence on radius and radius² over the finished
    # runs of SHAPE_RADII, well-mixed left out, fitted by Stats::QuadraticLogistic. It reads
    # "peaks at an intermediate reach" where the radius² coefficient is negative, its
    # two-sided Wald p is below SHAPE_LEVEL and the fitted peak lies strictly inside
    # SHAPE_RADII's range. It is fitted only on at least MIN_SHAPE_RADII radii with a
    # finished run, and with at least one emerged and one not-emerged run among them.
    SHAPE_RADII = (RADIUS_ORDER - [WELL_MIXED]).freeze
    SHAPE_LEVEL = 0.05
    MIN_SHAPE_RADII = 3

    OUTCOME_LABELS = { shown: "shown", not_shown: "not shown", refuted: "refuted", untested: "not yet tested",
                       no_fit: "no fit" }.freeze
    OUTCOME_BADGES = { shown: "badge-success", not_shown: "badge-warning", refuted: "badge-error",
                       untested: "badge-info", no_fit: "badge-info" }.freeze

    RUN_COLUMNS = %w[radius seed run_id status emerged emergence_epoch].freeze
    ARM_COLUMNS = %w[arm runs finished emerged rate].freeze
  end
end
