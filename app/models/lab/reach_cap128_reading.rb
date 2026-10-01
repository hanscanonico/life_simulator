# frozen_string_literal: true

module Lab
  # The numbers the reach-cap128 sweep was pre-registered with (`docs/design_record.md`,
  # 2026-10-01, "Does the reach effect carry to growable tapes?"). The sweep's reading,
  # Experiments::ReachCap128ReadingService, reads them from here, so the entry and the code
  # name one set of values.
  module ReachCap128Reading
    TREATMENT_RADIUS = 4

    # Sweep 9's economy-off control at cap 128, radius 1: its founding runs are the arm the
    # sweep is read against.
    CONTROL_EXPERIMENT = "host-parasite"
    CONTROL_ARM = { "energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 128 }.freeze

    # Emergence on the stored worlds, the one reading both arms carry: a finished run
    # emerged where it has a confirmed emergence epoch and the orientation-aware census of
    # some world it kept, at or after that epoch, reads `replicator_share` of at least
    # MIN_SHARE. A run counts only once the readings pass has read every world it kept.
    INSTRUMENT = DescendantReading::INSTRUMENT
    SHARE_KEY = DescendantReading::SHARE_KEY
    MIN_SHARE = 0.5

    # H-reach128: one one-sided Fisher exact test of emerged over counted, radius 4 above the
    # control, shown at p below LEVEL.
    LEVEL = 0.05

    # Descriptive: an emerged world whose terminal stored world reads at least this share is
    # an eligible parent. No later sweep's parent rule is locked by it.
    PARENT_SHARE = 0.5

    # Read off each emerged run's last live sample.
    RAW_LEN_KEY = "dominant_raw_len"
    INSTRUCTION_KEY = "dominant_instruction_count"
    # Read off its terminal stored world, beside the share.
    SELF_REPLICATES_KEY = "dominant_self_replicates"

    OUTCOME_LABELS = { shown: "shown", not_shown: "not shown", refuted: "refuted", untested: "not yet tested" }.freeze
    OUTCOME_BADGES = { shown: "badge-success", not_shown: "badge-warning", refuted: "badge-error",
                       untested: "badge-info" }.freeze

    RUN_COLUMNS = %w[
      arm seed run_id status emergence_epoch measured emerged terminal_share dominant_raw_len
      dominant_instruction_count dominant_self_replicates
    ].freeze
    ARM_COLUMNS = %w[
      arm runs finished counted emerged rate median_emergence_epoch median_terminal_share median_dominant_raw_len
      median_dominant_instruction_count self_replicating_dominant eligible_parents
    ].freeze
  end
end
