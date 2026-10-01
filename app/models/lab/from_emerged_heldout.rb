# frozen_string_literal: true

module Lab
  # The numbers of the from-emerged sweep's held-out confirmatory reading
  # (`docs/design_record.md`, 2026-09-25, "The from-emerged economy arms, confirmed on
  # held-out parents"). Its rules were written after the interim reading and an exploratory
  # look at the first ten parents' children, so they are read only on the children of
  # parents none of whose children had been seen.
  module FromEmergedHeldout
    # A held-out parent comes from sweep 9's extension, seeds 91–270, and is not one of the
    # ten parents whose children were seen. Run 2568 (seed 102) is an extension parent whose
    # twelve children were among the 120 seen, so the seed alone does not hold them out.
    LAST_SEEN_SEED = 90
    SEEN_PARENT_IDS = [944, 950, 967, 991, 1007, 1029, 1087, 1089, 1103, 2568].freeze

    # Samples at epochs up to `parent_epoch` + SETTLING_WINDOW are the switch's transient and
    # read for neither a settled relapse nor latency: the exploratory look found crashes at
    # the treatment switch that recover within it.
    SETTLING_WINDOW = 1_000

    # A settled relapse is RELAPSE_RUN samples running below RELAPSE_SHARE past the window;
    # a child is extinct where its last-decile median share is below EXTINCT_SHARE.
    RELAPSE_SHARE = DescendantReading::FLOOR_SHARE
    RELAPSE_RUN = DescendantReading::FLOOR_RUN
    EXTINCT_SHARE = 0.1

    # H3-latency: `copy_latency`, last-decile median over first-decile median, over the
    # samples past the window that carry it. Fewer than MIN_DECILE_SAMPLES in either decile
    # leaves a child unmeasured.
    LATENCY_KEY = "copy_latency"
    MIN_DECILE_SAMPLES = 10

    # The sign test and its leave-parents-out robustness are the original entry's.
    SIGN_TEST_LEVEL = DescendantReading::SIGN_TEST_LEVEL

    OUTCOME_LABELS = { held: "shown", not_shown: "not shown", refuted: "refuted",
                       no_pairs: "no measured pairs" }.freeze
    OUTCOME_BADGES = { held: "badge-success", not_shown: "badge-warning", refuted: "badge-error",
                       no_pairs: "badge-info" }.freeze

    CHILD_COLUMNS = %w[
      run_id parent seed treatment status settled_relapse_epoch extinct first_decile_latency last_decile_latency
      latency_ratio survivor complexity
    ].freeze
    ARM_COLUMNS = %w[treatment children finished settled_relapses extinct latency_measured survivors].freeze
    TEST_COLUMNS = %w[
      hypothesis treatment measured_pairs favour_treatment favour_continuation ties p_value outcome carried_by
    ].freeze
    AGREEMENT_COLUMNS = %w[hypothesis treatment parent favour_treatment favour_continuation ties unmeasured].freeze

    def self.held_out?(parent) = parent.seed > LAST_SEEN_SEED && SEEN_PARENT_IDS.exclude?(parent.id)
  end
end
