# frozen_string_literal: true

module Lab
  # The numbers the genes-rise sweep was pre-registered with (`docs/design_record.md`,
  # 2026-10-04, "Genes rise: does held code keep rising late, at a cap the run does not reach,
  # with nothing paid?"). The sweep reads its parent rule and its four bundles from here and
  # Experiments::GenesRiseReadingService reads the rest, so the entry and the code name one set
  # of values. Every per-child rule is the topless-rise entry's (Lab::ToplessRiseReading), with
  # the study's §5.1 clause 4 and a magnitude on top.
  module GenesRiseReading
    # The parents: reach-cap128's eligible parents under out-compute's rule (radius 4, emerged,
    # terminal world at least half replicators: 108 runs), the out-compute sweep's 54 set aside
    # (they hold the study's pilot worlds 4381 and 4428), then the PARENT_COUNT with the lowest
    # run ids, each from its terminal world. Their history is fitness-free and no pilot ran on
    # them.
    SKIP_FIRST = OutComputeReading::PARENT_COUNT
    PARENT_COUNT = 30
    PARENTS = OutComputeReading::PARENTS.merge("skip_first" => SKIP_FIRST, "first" => PARENT_COUNT).freeze

    # The cap the run does not reach, and the paired control's, which it does. Pilot 8's
    # longest tapes at α 0.03 project to 3 690–3 860 bytes at 60 000 epochs (`docs/studies/
    # unassisted.md` §13); a child that reaches the cap anyway is read as it stands and
    # counted near it.
    UNREACHED_CAP = 4096
    CAPPED_CAP = 1024
    # The shadow's coin: the pooled lower median of pilot 8's α 0.03 count lanes'
    # `predation_relation_rate` over their second half (0.333 over 110 census rows).
    SHADOW_P = 0.33
    # A sample every 100 epochs rather than the runner's 10: the persistence run of five
    # samples spans 500 epochs, and H-room's windows the pilot's five 500-epoch census rows. A
    # stored world every 500 epochs, for disk, as out-compute's.
    SAMPLE_EVERY = 100
    SNAPSHOT_EVERY = OutComputeReading::SNAPSHOT_EVERY

    # What every arm switches on, each value named: out-compute's economy, ladder, NAND, assay
    # and predation pass; the growable channel with duplication and deletion of segments; genes
    # of 32 bytes; staged costly fidelity at α 0.03. The arms differ in the relation and the cap
    # alone.
    BUNDLE = {
      "energy_payer" => "initiator", "energy_influx" => 1024, "energy_stock_cap" => 65_536, "steal_amount" => 0,
      "tasks" => "logic4", "task_reward" => 0, "logic_nand" => "stack", "task_max_outputs" => 16,
      "meta_len" => 32, "meta_min_len" => 8, "meta_dup" => 0.05, "meta_del" => 0.05, "meta_seg_max" => 16,
      "meta_rate" => 0.0009765625, "meta_draw" => "isa", "meta_seed" => "own_tape", "meta_genes" => 32,
      "meta_fid_max" => 16, "meta_fid_rate" => 0.05, "meta_fid_alpha" => 0.03,
      "predation_transfer" => 8192, "predation_loss" => 0.5, "predation_every" => 8, "predation_shadow_p" => SHADOW_P,
      "sample_every" => SAMPLE_EVERY, "snapshot_every" => SNAPSHOT_EVERY
    }.freeze
    COUNT_BUNDLE = BUNDLE.merge("predation" => "count", "meta_max_len" => UNREACHED_CAP).freeze
    CAPPED_BUNDLE = BUNDLE.merge("predation" => "count", "meta_max_len" => CAPPED_CAP).freeze
    SHADOW_BUNDLE = BUNDLE.merge("predation" => "shadow", "meta_max_len" => UNREACHED_CAP).freeze
    DRIFT_BUNDLE = BUNDLE.merge("predation" => "off", "meta_max_len" => UNREACHED_CAP).freeze

    SEEDS = [6201].freeze
    EPOCHS = 60_000
    PRIORITY = 40

    # Out-compute's label: every arm imports a machine, the drift arm included, since its
    # fidelity level is heritable and priced (`priced_fidelity_run?`).
    LABEL = OutComputeReading::LABEL

    # A run whose fidelity level is priced: `meta_fid_max` and `meta_fid_alpha` both positive
    # JSON numbers (the engine refuses a price off the initiator economy). The initiator pays
    # for its level, so the level is selected on and the energy flow reads a machine the world
    # was given, predation or not: never pooled with plain Soup. Run's `priced_fidelity` scope
    # is the same rule in SQL; keep the two in step.
    FIDELITY_MAX_KEY = "meta_fid_max"
    FIDELITY_ALPHA_KEY = "meta_fid_alpha"

    def self.priced_fidelity_run?(params)
      [FIDELITY_MAX_KEY, FIDELITY_ALPHA_KEY].all? do |key|
        value = params[key]
        value.is_a?(Numeric) && value.positive?
      end
    end

    SETTLING_WINDOW = ToplessRiseReading::SETTLING_WINDOW
    EXTINCT_SHARE = ToplessRiseReading::EXTINCT_SHARE
    MIN_DECILE_SAMPLES = ToplessRiseReading::MIN_DECILE_SAMPLES
    SIGN_TEST_LEVEL = ToplessRiseReading::SIGN_TEST_LEVEL
    PERSISTENCE_RUN = ToplessRiseReading::PERSISTENCE_RUN
    RISE_STEP = ToplessRiseReading::RISE_STEP
    DECILES = ToplessRiseReading::DECILES
    KEPT_SUFFIX = ToplessRiseReading::KEPT_SUFFIX
    SHARE_KEY = DescendantReading::SHARE_KEY
    CLASSES_KEY = ToplessRiseReading::CLASSES_KEY
    GENES_KEY = "genes_essential_held"
    LENGTH_KEY = "meta_len_mean"

    # A late rise on a key: the rise rule (the last-decile median at least RISE_STEP above the
    # bar), the study's §5.1 clause 4 (at least MAXIMA_NEEDED distinct persistent new maxima
    # above the value at descent, the last in the final quarter of the settled samples cut by
    # index) and the magnitude (the last-decile median at least MAGNITUDE times the bar).
    MAXIMA_NEEDED = 3
    FINAL_QUARTER = Rational(3, 4)
    MAGNITUDE = Rational(6, 5)

    # H-room's final-quarter gain: the lower median of the last ROOM_WINDOW samples of the
    # final quarter minus that of its first ROOM_WINDOW, each window read under
    # MIN_DECILE_SAMPLES numbers left unread. 25 samples are 2 500 epochs at SAMPLE_EVERY.
    ROOM_WINDOW = 25

    # McShea's minimum, offline: the MINIMUM_PERCENTILE of classes per computing cell, on the
    # fifth-decile and the last stored worlds (`research/landscape`, the genes-aware slice that
    # lands before the reading), handed to the reading as `run_id,fifth_minimum,last_minimum`
    # rows. A late rise on it is the rise step and the magnitude from the fifth-decile world to
    # the last; two worlds carry no persistence run.
    MINIMUM_PERCENTILE = 10
    MINIMA_COLUMNS = %w[run_id fifth_minimum last_minimum].freeze

    # A child whose last-decile median mean length is at least this share of its cap is
    # counted near it: descriptive, the room the count arm was given running short.
    NEAR_CAP_SHARE = Rational(9, 10)
    GENE_LENGTH = BUNDLE.fetch("meta_genes")

    # Descriptive, as last-decile medians.
    DESCRIPTIVE_KEYS = %w[
      logic_depth_max meta_len_mean fidelity_p10 fidelity_p50 fidelity_p90 repertoire_mean silent_share
      predation_rate predation_relation_rate
    ].freeze

    TREATMENT_NAMES = { count: "count", capped: "capped", shadow: "shadow", drift: "drift" }.freeze

    # Each test: the treated arm, the control, and what a pair compares. `classes` and `genes`
    # the late rise on `logic_depth_classes` and on `genes_essential_held`, the side that rises
    # late alone favoured; `room` the final-quarter gain in `logic_depth_classes`, the larger
    # favoured; `minimum` the late rise on the offline minimum.
    HYPOTHESES = {
      "H-rise" => %i[count drift classes],
      "H-rise-genes" => %i[count drift genes],
      "H-room" => %i[count capped room],
      "H-shadow" => %i[count shadow classes],
      "H-driven" => %i[count drift minimum]
    }.freeze

    CHILD_COLUMNS = %w[
      run_id parent seed treatment status settled_relapse_epoch extinct
      classes_descent classes_bar classes_last classes_rises classes_maxima classes_last_maximum_epoch
      classes_late_rise
      genes_descent genes_bar genes_last genes_rises genes_maxima genes_last_maximum_epoch genes_late_rise
      final_quarter_epoch room_first room_last room_gain minimum_fifth minimum_last minimum_late_rise
      logic_depth_max meta_len_mean near_cap classes_per_kb_fifth classes_per_kb essential_genes_per_gene
      fidelity_p10 fidelity_p50 fidelity_p90 repertoire_mean silent_share predation_rate predation_relation_rate
      replicator_share
    ].freeze
    ARM_COLUMNS = %w[
      treatment children finished settled_relapses extinct classes_measured classes_late_rises genes_late_rises
      room_measured minimum_late_rises near_cap median_last_decile_classes
    ].freeze
    # The Experiments::GenesRiseReadingService::ChildRow predicate each count after `children`
    # reads.
    ARM_COUNTS = %i[finished? settled_relapse? extinct? classes_measured? classes_late_rise? genes_late_rise?
                    room_measured? minimum_late_rise? near_cap?].freeze
    TEST_COLUMNS = LogicReading::TEST_COLUMNS
    AGREEMENT_COLUMNS = LogicReading::AGREEMENT_COLUMNS

    # The arm a child runs under, read off its relation and its cap; nil for any other.
    def self.treatment_key(params)
      cap = params["meta_max_len"]
      case params.fetch(OutComputeReading::PREDATION_KEY, OutComputeReading::OFF)
      when "count" then { UNREACHED_CAP => :count, CAPPED_CAP => :capped }[cap]
      when "shadow" then :shadow
      when OutComputeReading::OFF then :drift
      end
    end
  end
end
