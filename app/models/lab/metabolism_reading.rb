# frozen_string_literal: true

module Lab
  # The numbers the metabolism sweep was pre-registered with (`docs/design_record.md`,
  # 2026-10-01, "Metabolism: a second, labelled substrate that imports an objective"). The
  # sweep reads its two bundles from here and Experiments::MetabolismReadingService reads
  # the rest, so the entry and the code name one set of values. The settling window, the
  # extinction and settled-relapse rules and the sign test are the held-out reading's
  # (Lab::FromEmergedHeldout), the deciles, the complexity rule, the per-parent agreement
  # and the leave-out rule the from-emerged reading's (Lab::DescendantReading).
  module MetabolismReading
    # The two arms, each merged over its parent's params. They share the initiator economy
    # and the assay, so the pair isolates the reward: at a reward of 0 nothing pays a task
    # and the world runs as it would with `tasks` off, byte for byte.
    REWARD_BUNDLE = {
      "energy_payer" => "initiator", "energy_influx" => 1024, "energy_stock_cap" => 65_536, "steal_amount" => 0,
      "tasks" => "arith", "task_every" => 8, "task_reward" => 2048
    }.freeze
    NO_REWARD_BUNDLE = REWARD_BUNDLE.merge("task_reward" => 0).freeze

    # The label: a run paid for its tasks is a Metabolism run, imports an objective, and is
    # never pooled with a fitness-free arm.
    REWARD_KEY = "task_reward"
    LABEL = "Metabolism: imports an objective"

    SETTLING_WINDOW = FromEmergedHeldout::SETTLING_WINDOW
    EXTINCT_SHARE = FromEmergedHeldout::EXTINCT_SHARE

    # H-capability and H-ladder: the last-decile median of these, the reward child's against
    # its twin's. Fewer than MIN_DECILE_SAMPLES numbers in the last decile leaves a child
    # unmeasured on that key.
    CAPABILITY_KEY = "task_capability"
    LOOP_CAPABILITY_KEY = "task_capability_loop"
    MIN_DECILE_SAMPLES = DescendantReading::MIN_DECILE_SAMPLES

    SIGN_TEST_LEVEL = DescendantReading::SIGN_TEST_LEVEL

    # The parents the design study's pilot ran (lab run ids): every test is also read
    # without their pairs, a sensitivity reading that decides no outcome.
    PILOT_PARENTS = [1007, 2577, 1029, 2862].freeze
    UNPILOTED_SUFFIX = ", unpiloted parents"

    # The ladder, in the engine's order (`runner schema`, `tasks.ladder`); a task's share is
    # `task_share_<name>`. The loop rungs are the ones `task_capability_loop` counts, and
    # INC and DEC are the stepping stones a loop rung is read against.
    TASKS = %w[echo inc dec add sub not double mul].freeze
    LOOP_TASKS = %w[add sub not double mul].freeze
    STEPPING_STONES = %w[inc dec].freeze
    def self.share_key(task) = "task_share_#{task}"
    SHARE_KEYS = TASKS.map { |task| share_key(task) }.freeze

    # Descriptive: the first own sample at which a task's share reaches TASK_PRESENT_SHARE,
    # which is `task_capability`'s own line (26 of 256 cells).
    TASK_PRESENT_SHARE = 0.1

    DOMINANT_TASKS_KEY = "dominant_tasks"
    DOMINANT_TASK_COUNT_KEY = "dominant_task_count"
    LATENCY_KEY = FromEmergedHeldout::LATENCY_KEY
    SHARE_KEY = DescendantReading::SHARE_KEY
    # Read as last-decile medians, descriptively.
    DESCRIPTIVE_KEYS = [DOMINANT_TASK_COUNT_KEY, LATENCY_KEY, SHARE_KEY, *SHARE_KEYS].freeze

    TREATMENT_NAMES = { reward: "reward", no_reward: "no reward" }.freeze

    CHILD_COLUMNS = %w[
      run_id parent seed treatment status settled_relapse_epoch extinct capability loop_capability complexity
      first_decile_instructions last_decile_instructions first_echo first_inc first_dec first_add first_sub
      first_not first_double first_mul dominant_tasks dominant_task_count copy_latency replicator_share
      task_income_share
    ].freeze
    ARM_COLUMNS = %w[
      treatment children finished settled_relapses extinct capability_measured loop_children stepping_stone_children
      complexity_survivors rises
    ].freeze
    # The Experiments::MetabolismReadingService::ChildRow predicate each count after
    # `children` reads.
    ARM_COUNTS = %i[finished? settled_relapse? extinct? capability_measured? climbed_loop? stepping_stone?
                    complexity_survivor? surviving_rise?].freeze
    TEST_COLUMNS = %w[
      hypothesis treatment measured_pairs favour_reward favour_no_reward ties p_value outcome carried_by
    ].freeze
    AGREEMENT_COLUMNS = %w[hypothesis treatment parent favour_reward favour_no_reward ties unmeasured].freeze

    # The engine reads the reward only as a JSON number: a missing, null or non-numeric one
    # pays nothing. Run.metabolism is the same rule in SQL.
    def self.metabolism_run?(params)
      reward = params[REWARD_KEY]
      reward.is_a?(Numeric) && reward.positive?
    end
  end
end
