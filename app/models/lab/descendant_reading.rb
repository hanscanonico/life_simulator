# frozen_string_literal: true

module Lab
  # The numbers the from-emerged sweep was pre-registered with (`docs/design_record.md`,
  # 2026-09-25, "Runs that start from an emerged world"): which parents it starts from, and
  # how a child's own samples read. The sweep's builder reads the parent rule from here and
  # the sweep's reading reads the rest, so the entry and the code name one set of values.
  module DescendantReading
    # The orientation-aware census that sees reverse copiers (#245, #247); the engine's
    # locked census does not, so a parent is qualified on this reading of its stored world.
    INSTRUMENT = "oriented_census/1"
    SHARE_KEY = "replicator_share"
    # A parent qualifies where the reading of its terminal world holds at least this share.
    QUALIFYING_SHARE = 0.5

    # Persistence: a child holds its replicators when its last-decile share is at least
    # HELD_SHARE and the share never sat below FLOOR_SHARE for FLOOR_RUN samples running;
    # it relapsed otherwise.
    HELD_SHARE = 0.5
    FLOOR_SHARE = 0.1
    FLOOR_RUN = 3

    # Complexity: `dominant_instruction_count` over the samples whose dominant tape
    # self-replicates, last-decile median against first-decile median.
    COMPLEXITY_KEY = "dominant_instruction_count"
    REPLICATING_KEY = "dominant_self_replicates"
    RISE_FACTOR = 1.2
    PLATEAU_BAND = 0.1
    # Fewer self-replicating samples than this in either decile leaves a child unmeasured.
    MIN_DECILE_SAMPLES = 10

    # H-economy and H-host: a one-sided sign test over the discordant (parent, seed) pairs,
    # read at p below this; a significant test that falls to p at or above it once the pairs
    # of up to LEAVE_OUT_PARENTS parents are left out is stated as carried by them.
    SIGN_TEST_LEVEL = 0.05
    LEAVE_OUT_PARENTS = 2

    # Secondary and descriptive only: last-decile medians and the share trajectory, binned
    # by own epochs.
    STEAL_RATE = "steal_rate"
    DISTINCT_TAPES = "distinct_tapes"
    DESCRIPTIVE_KEYS = [STEAL_RATE, DISTINCT_TAPES].freeze
    TRAJECTORY_BIN = 1_000

    VERDICTS = %i[held relapsed rises plateau mixed unmeasured].freeze
    CHILD_COLUMNS = %w[
      run_id parent seed treatment status persistence relapse_epoch relapse_colony_age watched_colony_ages
      complexity first_decile_instructions last_decile_instructions
    ].freeze
    ARM_COLUMNS = %w[
      treatment children terminal held relapsed rises plateau mixed unmeasured last_decile_steal_rate
      last_decile_distinct_tapes
    ].freeze
    COMPARISON_COLUMNS = %w[
      hypothesis treatment measured_pairs favour_treatment favour_continuation ties p_value outcome reading carried_by
    ].freeze
    AGREEMENT_COLUMNS = %w[treatment parent favour_treatment favour_continuation ties unmeasured].freeze
  end
end
