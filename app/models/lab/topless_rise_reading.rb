# frozen_string_literal: true

module Lab
  # The numbers the topless-rise sweep was pre-registered with (`docs/design_record.md`,
  # 2026-10-02, "Topless rise: does the deepest rung held keep rising when depth is paid?").
  # The sweep reads its parent rule and its three bundles from here and
  # Experiments::ToplessRiseReadingService reads the rest, so the entry and the code name one
  # set of values. Extinction, relapse, deciles, medians, the sign test and its outcomes are
  # the logic entry's (Lab::LogicReading); the rise rule on `logic_depth_max` is this entry's.
  module ToplessRiseReading
    # The parents: every finished meta-stack-arm child of the meta-stack sweep (the stack NAND
    # paid from ECHO up: no floor, or the default one, stated), each from its last stored
    # world. Meta-stack's H-deep-Ms read shown on fewer than about ten parents, so the topless
    # study's rule (§3) takes all of them and reads the deep ones as a subgroup.
    PARENTS = {
      "experiment" => Lab.slug_for("meta_stack"),
      "descendants" => true,
      "arms" => [nil, LogicReading::TASKS.first].map { |floor| MetaStackReading::STACK_BUNDLE.merge("task_floor" => floor) }
    }.freeze

    # `task_reward` 512: with the influx 1 024, `task_every` 8 and the initiator's 8 192-step
    # ceiling, a cell saturates at 112 units, so no single rung up to the 13 floor (91 units
    # beside ECHO, NOT and XOR) saturates it and every NAND from 5 up is worth 7–31 % more
    # income. At 1 024 a depth-12 rung saturates alone.
    REWARD = 512
    # The capped arm pays any rung deeper than this as one of this depth: the study's §3.
    DEPTH_CAP = 5
    RISE_BUNDLE = { "tasks" => "logic4", "task_reward" => REWARD }.freeze
    CAPPED_BUNDLE = RISE_BUNDLE.merge("task_depth_cap" => DEPTH_CAP).freeze
    # A reward of 0 runs no assay, but the depth readings still read every sample.
    NONE_BUNDLE = { "tasks" => "logic4", "task_reward" => 0 }.freeze

    # One seed per parent, used by no stored run; the parent is already a (parent, seed) child.
    SEEDS = [4001].freeze
    EPOCHS = 100_000
    PRIORITY = 40

    LABEL = "Topless rise: imports an objective, a primitive, a hereditary channel, the primitive's " \
            "semantics and a ladder of growing input arity"

    SETTLING_WINDOW = LogicReading::SETTLING_WINDOW
    EXTINCT_SHARE = LogicReading::EXTINCT_SHARE
    MIN_DECILE_SAMPLES = LogicReading::MIN_DECILE_SAMPLES
    SIGN_TEST_LEVEL = LogicReading::SIGN_TEST_LEVEL
    PERSISTENCE_RUN = LogicReading::PERSISTENCE_RUN
    KEPT_SUFFIX = LogicReading::KEPT_SUFFIX
    DEEP_SUFFIX = ", deep subgroup"

    # The minimal NAND count of the deepest rung held by a tenth of the sampled cells; −1
    # where none is held, a number below every depth that enters a median as itself.
    DEPTH_KEY = "logic_depth_max"
    CLASSES_KEY = "logic_depth_classes"
    NOTHING_HELD = -1

    # The rise rule: a child rises late where its last-decile median depth is at least its
    # fifth-decile median + RISE_STEP. Deciles cut the settled samples by index, decile k the
    # samples from floor((k − 1)·n/10) to before floor(k·n/10), so the tenth is Logic's last
    # ceil(n/10).
    RISE_DECILE = 5
    DECILES = 10
    RISE_STEP = 1
    # The four-input table's "13 or more" functions are credited at 13
    # (`runner schema`, `tasks.topless.depth_floor`), so 13 is both the floor and the deepest
    # depth a reading can show: a child already there at its fifth decile cannot rise, and is
    # read as no rise and counted apart.
    CEILING_DEPTH = 13

    # Meta-stack's deep children (H-deep-Ms's nine, `lab:meta_stack_report` final), the
    # declared subgroup every test is read again on.
    DEEP_PARENTS = [4845, 4862, 4863, 4871, 4890, 4952, 4961, 4979, 4980].freeze

    # H-rise-code, descriptive and measured offline (a `research/landscape` slice before the
    # sweep is read): the load-bearing bytes of the dominant deepest solver on six fixed
    # four-input case sets, drawn in turn off `rng::seeded(*CODE_CASE_SEED)`; a byte bears
    # load where at least CODE_BEARING_SYMBOLS of the 13 other symbols leave no class as deep
    # credited on all six, and the code is new where the count rose by CODE_NEW_BYTES.
    CODE_CASE_SETS = 6
    CODE_CASE_SEED = [0xdee9, 4, 0].freeze
    CODE_BEARING_SYMBOLS = 7
    CODE_NEW_BYTES = 2

    TREATMENT_NAMES = { rise: "rise", capped: "capped", none: "none" }.freeze

    # Each test: the treated arm and the control.
    HYPOTHESES = {
      "H-rise" => %i[rise none],
      "H-rise-paid" => %i[rise capped]
    }.freeze

    CHILD_COLUMNS = %w[
      run_id parent seed treatment status deep_parent settled_relapse_epoch extinct fifth_decile_depth
      last_decile_depth rises ceilinged deepest_held deepest_held_epoch late_depths reached_floor
      last_decile_classes replicator_share
    ].freeze
    ARM_COLUMNS = %w[treatment children finished settled_relapses extinct measured rises ceilinged reached_floor].freeze
    # The Experiments::ToplessRiseReadingService::ChildRow predicate each count after
    # `children` reads.
    ARM_COUNTS = %i[finished? settled_relapse? extinct? rise_measured? rises? ceilinged? reached_floor?].freeze
    TEST_COLUMNS = LogicReading::TEST_COLUMNS
    AGREEMENT_COLUMNS = LogicReading::AGREEMENT_COLUMNS

    # The arm a child runs under: no reward, depth paid up to the cap, or depth paid.
    def self.treatment_key(params)
      return :none unless MetabolismReading.metabolism_run?(params)

      params.fetch("task_depth_cap", 0).to_i.positive? ? :capped : :rise
    end
  end
end
