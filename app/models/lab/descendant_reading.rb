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
  end
end
