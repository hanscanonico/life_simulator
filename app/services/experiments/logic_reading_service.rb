# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the logic sweep (`docs/design_record.md`, 2026-10-01,
  # "Logic: does a soup assemble features beyond its one-step rungs when the parts are
  # paid?"), Experiments::MetabolismReadingService's reading over three arms. Each child is
  # read over its own samples past the settling window, under the held-out reading's
  # extinction and settled-relapse rules (Lab::FromEmergedHeldout::Child) and the
  # from-emerged complexity rule (Lab::DescendantReading::Child), plus the logic readings of
  # Lab::LogicReading::Child. Each full child is paired with the none child (H-capability-L,
  # H-deep, H-complexity) and the deep-only child (H-stones) of the same (parent, seed), and
  # every sign test (Lab::DescendantReading::Comparison) is read again with the extinct pairs
  # kept and without the piloted parents, as sensitivity readings. It is interim until the
  # parent pool is settled and every child of every qualifying parent has finished.
  #
  # It reads stored samples, one child at a time, and changes nothing.
  class LogicReadingService
    include Callable
    include ReadsLogicChildren

    SAMPLE_KEYS = [
      Lab::DescendantReading::SHARE_KEY, Lab::DescendantReading::REPLICATING_KEY,
      Lab::DescendantReading::COMPLEXITY_KEY, Lab::LogicReading::CAPABILITY_KEY,
      Lab::LogicReading::DEEP_CAPABILITY_KEY, Lab::LogicReading::DOMINANT_TASKS_KEY,
      *Lab::LogicReading::DESCRIPTIVE_KEYS
    ].uniq.freeze
    DESCRIPTIVE_KEYS = Lab::LogicReading::DESCRIPTIVE_KEYS

    Treatment = Data.define(:key, :name)

    TREATMENTS = Lab::LogicReading::TREATMENT_NAMES.map { |key, name| Treatment.new(key: key, name: name) }.freeze

    # `reading` is the from-emerged rule's over the settled samples, `heldout` the held-out
    # entry's, `logic` the logic readings; `income_share` the descriptive estimate of the
    # share of income that comes from tasks.
    ChildRow = Data.define(:run_id, :parent_id, :seed, :treatment, :status, :reading, :heldout, :logic,
                           :income_share) do
      delegate :capability, :climbed_deep?, :stepping_stone?, to: :logic

      def finished? = status == "finished"

      def settled_relapse? = !heldout.settled_relapse_epoch.nil?

      def extinct? = heldout.extinct == true

      # Read and carrying the key; not extinct unless `keep_extinct`.
      def capability_measured?(key = Lab::LogicReading::CAPABILITY_KEY, keep_extinct: false)
        heldout.read && (keep_extinct || !heldout.extinct) && !capability(key).nil?
      end

      # Measured under the complexity rule and survived: neither extinct nor relapsed past
      # the window, unless `keep_extinct` drops both share rules.
      def complexity_measured?(keep_extinct: false)
        (keep_extinct ? heldout.read : heldout.survivor?) && reading.measured?
      end

      def complexity_survivor? = complexity_measured?

      def surviving_rise? = complexity_survivor? && reading.rises?

      def cells
        [run_id, parent_id, seed, treatment.name, status, heldout.settled_relapse_epoch, heldout.extinct,
         capability(Lab::LogicReading::CAPABILITY_KEY), capability(Lab::LogicReading::DEEP_CAPABILITY_KEY),
         reading.complexity, reading.first_instructions, reading.last_instructions,
         *logic.first_epochs.values_at(*Lab::LogicReading::TASKS), logic.dominant_tasks,
         *[Lab::LogicReading::DOMINANT_TASK_COUNT_KEY, Lab::LogicReading::LATENCY_KEY,
           Lab::LogicReading::SHARE_KEY].map { |key| reading.last_median(key) },
         income_share]
      end
    end

    # Each hypothesis: the key its pairs compare (nil for the complexity rule) and the arm
    # the full arm is read against.
    HYPOTHESES = {
      "H-capability-L" => [Lab::LogicReading::CAPABILITY_KEY, :none],
      "H-deep" => [Lab::LogicReading::DEEP_CAPABILITY_KEY, :none],
      "H-stones" => [Lab::LogicReading::DEEP_CAPABILITY_KEY, :deep_only],
      "H-complexity" => [nil, :none]
    }.freeze

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("logic")

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::LogicReading::Report.new(children: children, arms: arms, tests: tests, kept_tests: tests(keep_extinct: true),
                                    unpiloted_tests: tests(unpiloted: true),
                                    final: DescendantSweepSettledService.call(@experiment))
    end

    private

    def arms
      @arms ||= TREATMENTS.map do |treatment|
        Lab::LogicReading::Arm.new(treatment: treatment,
                                   children: children.select { |child| child.treatment == treatment })
      end
    end

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    # `keep_extinct` re-reads each test with the pairs of extinct children kept; `unpiloted`
    # without the pairs of Lab::LogicReading::PILOT_PARENTS.
    def tests(keep_extinct: false, unpiloted: false)
      full = arm(:full)
      treated = unpiloted ? full.children.reject { |child| piloted?(child) } : full.children
      suffix = if keep_extinct then Lab::LogicReading::KEPT_SUFFIX
               elsif unpiloted then Lab::LogicReading::UNPILOTED_SUFFIX
               end

      HYPOTHESES.map do |hypothesis, (key, control_key)|
        control = arm(control_key)
        twins = control.children.index_by { |child| [child.parent_id, child.seed] }
        pairs = treated.map { |child| pair(key, keep_extinct, child, twins[[child.parent_id, child.seed]]) }
        Lab::LogicReading::Test.new(hypothesis: "#{hypothesis}#{suffix}", treatment: full.treatment,
                                    control: control.treatment,
                                    comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false))
      end
    end

    def piloted?(child) = Lab::LogicReading::PILOT_PARENTS.include?(child.parent_id)

    def pair(key, keep_extinct, treated, control)
      if key
        Lab::LogicReading::Pairs::Capability.new(key: key, keep_extinct: keep_extinct, parent_id: treated.parent_id,
                                                 seed: treated.seed, treated: treated, control: control)
      else
        Lab::LogicReading::Pairs::Complexity.new(keep_extinct: keep_extinct, parent_id: treated.parent_id,
                                                 seed: treated.seed, treated: treated, control: control)
      end
    end

    def children
      @children ||= child_runs.map { |run| child_row(run) }
    end

    def child_row(run)
      ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment_of(run),
                   status: run.status, **logic_child_reading(run))
    end

    def treatment_of(run)
      key = Lab::LogicReading.treatment_key(run.params)
      TREATMENTS.find { |treatment| treatment.key == key }
    end

    def child_runs = @child_runs ||= descendant_runs(@experiment)
  end
end
