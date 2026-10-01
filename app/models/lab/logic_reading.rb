# frozen_string_literal: true

module Lab
  # The numbers the logic sweep was pre-registered with (`docs/design_record.md`, 2026-10-01,
  # "Logic: does a soup assemble features beyond its one-step rungs when the parts are
  # paid?"). The sweep reads its three bundles from here and Experiments::LogicReadingService
  # reads the rest, so the entry and the code name one set of values. Every rule the entry
  # takes from the Metabolism reading is Lab::MetabolismReading's, and through it the
  # held-out reading's (Lab::FromEmergedHeldout) and the from-emerged reading's
  # (Lab::DescendantReading).
  module LogicReading
    # The three arms, each merged over its parent's params. They share the initiator economy
    # and the logic assay. `none` differs from Metabolism's no-reward bundle in `tasks` alone,
    # and a reward of 0 runs no assay, so its worlds are that arm's byte for byte; it is run
    # for the logic readings its samples carry.
    FULL_BUNDLE = MetabolismReading::REWARD_BUNDLE.merge("tasks" => "logic").freeze
    DEEP_FLOOR = "xor"
    DEEP_ONLY_BUNDLE = FULL_BUNDLE.merge("task_floor" => DEEP_FLOOR).freeze
    NONE_BUNDLE = FULL_BUNDLE.merge("task_reward" => 0).freeze

    # A rewarded logic run is a Metabolism run (MetabolismReading.metabolism_run?), and it
    # imports a primitive besides.
    LABEL = "Logic: imports an objective and a primitive"

    SETTLING_WINDOW = MetabolismReading::SETTLING_WINDOW
    EXTINCT_SHARE = MetabolismReading::EXTINCT_SHARE
    MIN_DECILE_SAMPLES = MetabolismReading::MIN_DECILE_SAMPLES
    SIGN_TEST_LEVEL = MetabolismReading::SIGN_TEST_LEVEL

    # H-capability-L reads the first, H-deep and H-stones the second: last-decile medians.
    CAPABILITY_KEY = "logic_capability"
    DEEP_CAPABILITY_KEY = "logic_capability_deep"

    # The parents the design study's pilots ran (lab run ids): every test is also read
    # without their pairs, a sensitivity reading that decides no outcome.
    PILOT_PARENTS = [1007, 944, 2577, 2700].freeze
    UNPILOTED_SUFFIX = ", unpiloted parents"
    # The other sensitivity reading (study §5.6): every test with the pairs whose children
    # read as extinct kept, since a world of partial copiers reads a low `replicator_share`.
    KEPT_SUFFIX = ", extinct kept"

    # The ladder, in the engine's order (`runner schema`, `tasks.logic.ladder`); a rung's
    # share is `logic_share_<name>`. The deep rungs are the ones `logic_capability_deep`
    # counts, and OR, ANDN and NOR the stepping stones a deep rung is read against.
    TASKS = %w[echo not nand and orn or andn nor xor equ].freeze
    DEEP_TASKS = %w[xor equ].freeze
    STEPPING_STONES = %w[or andn nor].freeze
    def self.share_key(task) = "logic_share_#{task}"
    SHARE_KEYS = TASKS.map { |task| share_key(task) }.freeze

    # Descriptive: a rung reaches the line at the first of PERSISTENCE_RUN consecutive own
    # samples whose share is at least TASK_PRESENT_SHARE (26 of 256 cells). A masked circuit
    # that computes a rung on a share p of inputs is credited on about p³ of samples, at most
    # 0.077 for the commonest the assay's review found, and about 4 000 own samples hold
    # n·q⁵ < 0.02 runs of five by chance.
    TASK_PRESENT_SHARE = 0.1
    PERSISTENCE_RUN = 5

    DOMINANT_TASKS_KEY = "dominant_logic_tasks"
    DOMINANT_TASK_COUNT_KEY = "dominant_logic_task_count"
    LATENCY_KEY = MetabolismReading::LATENCY_KEY
    SHARE_KEY = MetabolismReading::SHARE_KEY
    # Read as last-decile medians, descriptively.
    DESCRIPTIVE_KEYS = [DOMINANT_TASK_COUNT_KEY, LATENCY_KEY, SHARE_KEY, *SHARE_KEYS].freeze

    TREATMENT_NAMES = { full: "full", deep_only: "deep-only", none: "none" }.freeze

    CHILD_COLUMNS = %w[
      run_id parent seed treatment status settled_relapse_epoch extinct capability deep_capability complexity
      first_decile_instructions last_decile_instructions first_echo first_not first_nand first_and first_orn
      first_or first_andn first_nor first_xor first_equ dominant_logic_tasks dominant_logic_task_count
      copy_latency replicator_share task_income_share
    ].freeze
    ARM_COLUMNS = %w[
      treatment children finished settled_relapses extinct capability_measured deep_children stepping_stone_children
      complexity_survivors rises
    ].freeze
    # The Experiments::LogicReadingService::ChildRow predicate each count after `children`
    # reads.
    ARM_COUNTS = %i[finished? settled_relapse? extinct? capability_measured? climbed_deep? stepping_stone?
                    complexity_survivor? surviving_rise?].freeze
    TEST_COLUMNS = %w[
      hypothesis treatment control measured_pairs favour_treatment favour_control ties p_value outcome carried_by
    ].freeze
    AGREEMENT_COLUMNS = %w[
      hypothesis treatment control parent favour_treatment favour_control ties unmeasured
    ].freeze

    # The treatment a logic child runs under, read off its params: no reward, the deep rungs
    # alone paid, or the whole ladder.
    def self.treatment_key(params)
      return :none unless MetabolismReading.metabolism_run?(params)

      params["task_floor"] == DEEP_FLOOR ? :deep_only : :full
    end
  end
end
