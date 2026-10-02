# frozen_string_literal: true

module Lab
  # The numbers the meta-stack sweep was pre-registered with (`docs/design_record.md`,
  # 2026-10-02, "Meta-stack: does a soup assemble the deep rungs from paid parts on a
  # metabolism tape read with a stack NAND?"). The sweep reads its three bundles from here and
  # Experiments::MetaStackReadingService reads the rest, so the entry and the code name one
  # set of values. Every reading rule is the logic entry's (Lab::LogicReading), and its pairs
  # cross into the logic sweep for their unpaid and woven twins.
  module MetaStackReading
    # The metabolism tape every arm switches on, its four parameters named explicitly.
    META_BUNDLE = {
      "meta_len" => 32, "meta_rate" => 0.00390625, "meta_draw" => "isa", "meta_seed" => "own_tape"
    }.freeze
    # The three arms, each merged over its parent's params, on top of the Logic full bundle.
    STACK_BUNDLE = LogicReading::FULL_BUNDLE.merge(META_BUNDLE, "logic_nand" => "stack").freeze
    STACK_DEEP_ONLY_BUNDLE = STACK_BUNDLE.merge("task_floor" => LogicReading::DEEP_FLOOR).freeze
    IN_PLACE_BUNDLE = LogicReading::FULL_BUNDLE.merge(META_BUNDLE, "logic_nand" => "in_place").freeze

    LABEL = "Meta-stack: imports an objective, a primitive, a hereditary channel and a choice of the " \
            "primitive's semantics made because it lets the deep rungs come"

    # The experiment whose children are this sweep's twins, paired by (parent, seed): its none
    # child (no reward, no metabolism tape) and its full child (the woven tape, paid).
    TWIN_SWEEP = "logic"

    SETTLING_WINDOW = LogicReading::SETTLING_WINDOW
    EXTINCT_SHARE = LogicReading::EXTINCT_SHARE
    MIN_DECILE_SAMPLES = LogicReading::MIN_DECILE_SAMPLES
    SIGN_TEST_LEVEL = LogicReading::SIGN_TEST_LEVEL
    CAPABILITY_KEY = LogicReading::CAPABILITY_KEY
    DEEP_CAPABILITY_KEY = LogicReading::DEEP_CAPABILITY_KEY
    PILOT_PARENTS = LogicReading::PILOT_PARENTS
    UNPILOTED_SUFFIX = LogicReading::UNPILOTED_SUFFIX
    KEPT_SUFFIX = LogicReading::KEPT_SUFFIX
    PERSISTENCE_RUN = LogicReading::PERSISTENCE_RUN
    TASK_PRESENT_SHARE = LogicReading::TASK_PRESENT_SHARE

    # Descriptive, as last-decile medians beside Logic's: how often an interaction hands a
    # metabolism tape on, how varied the tapes are, and the capability of the replicating
    # tape's own circuits.
    META_KEYS = %w[meta_inherit_rate meta_diversity logic_capability_replicating].freeze
    DESCRIPTIVE_KEYS = [*LogicReading::DESCRIPTIVE_KEYS, *META_KEYS].freeze

    # An arm is read off a child's params by its reward, its metabolism tape, its NAND and its
    # floor: [paid, tape on, logic_nand, paid from XOR up].
    ARMS = {
      [true, true, "stack", false] => :meta_stack,
      [true, true, "stack", true] => :meta_stack_deep_only,
      [true, true, "in_place", false] => :meta_inplace,
      [false, false, "in_place", false] => :logic_none,
      [true, false, "in_place", false] => :logic_full
    }.freeze
    TREATMENT_NAMES = {
      meta_stack: "meta-stack", meta_stack_deep_only: "meta-stack-deep-only", meta_inplace: "meta-inplace",
      logic_none: "logic-none", logic_full: "logic-full"
    }.freeze
    # The arms read from the logic sweep rather than this one.
    TWIN_ARMS = %i[logic_none logic_full].freeze

    # Each test: the key its pairs compare, the treated arm and the control arm.
    HYPOTHESES = {
      "H-deep-Ms" => [DEEP_CAPABILITY_KEY, :meta_stack, :logic_none],
      "H-stones-Ms" => [DEEP_CAPABILITY_KEY, :meta_stack, :meta_stack_deep_only],
      "H-stack" => [DEEP_CAPABILITY_KEY, :meta_stack, :meta_inplace],
      "H-deep-M" => [DEEP_CAPABILITY_KEY, :meta_inplace, :logic_none],
      "H-decouple" => [DEEP_CAPABILITY_KEY, :meta_inplace, :logic_full],
      "H-capability-M" => [CAPABILITY_KEY, :meta_stack, :logic_none]
    }.freeze

    CHILD_COLUMNS = [*LogicReading::CHILD_COLUMNS, *META_KEYS].freeze
    ARM_COLUMNS = LogicReading::ARM_COLUMNS
    TEST_COLUMNS = LogicReading::TEST_COLUMNS
    AGREEMENT_COLUMNS = LogicReading::AGREEMENT_COLUMNS
    PAIR_COLUMNS = %w[parent seed].concat(
      TREATMENT_NAMES.values.flat_map { |name| %W[#{name} #{name}_deep #{name}_replicator_share] }
    ).freeze

    # The arm a child runs under, or nil for a child of neither sweep's arms here (the logic
    # sweep's deep-only arm).
    def self.treatment_key(params)
      ARMS[[MetabolismReading.metabolism_run?(params), params.fetch("meta_len", 0).to_i.positive?,
            params.fetch("logic_nand", "in_place"), params["task_floor"] == LogicReading::DEEP_FLOOR]]
    end
  end
end
