# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the meta-stack sweep (`docs/design_record.md`, 2026-10-02,
  # "Meta-stack: does a soup assemble the deep rungs from paid parts on a metabolism tape
  # read with a stack NAND?"): Experiments::LogicReadingService's reading over five arms, the
  # sweep's own three and two twins from the logic sweep. Every child is read by the logic
  # entry's rules (ReadsLogicChildren). Its arm is keyed on its reward, `meta_len`,
  # `logic_nand` and `task_floor` (Lab::MetaStackReading.treatment_key), so the logic
  # sweep's none child (no reward, no tape) and full child (the woven tape, paid) of the same
  # (parent, seed) are the twins the tests pair across sweeps; its deep-only child is in no
  # arm here. Every sign test is read again with the extinct pairs kept and without the
  # piloted parents. It is interim until both sweeps have settled.
  #
  # It reads stored samples, one child at a time, and changes nothing.
  class MetaStackReadingService
    include Callable
    include ReadsLogicChildren

    SAMPLE_KEYS = [*LogicReadingService::SAMPLE_KEYS, *Lab::MetaStackReading::META_KEYS].uniq.freeze
    DESCRIPTIVE_KEYS = Lab::MetaStackReading::DESCRIPTIVE_KEYS

    Treatment = LogicReadingService::Treatment

    TREATMENTS = Lab::MetaStackReading::TREATMENT_NAMES.map { |key, name| Treatment.new(key: key, name: name) }.freeze

    # A logic child's row, with the metabolism tape's descriptive medians after Logic's.
    class ChildRow < LogicReadingService::ChildRow
      def cells = [*super, *Lab::MetaStackReading::META_KEYS.map { |key| reading.last_median(key) }]
    end

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("meta_stack")

    def self.twin_experiment = Experiment.find_by(slug: Lab.slug_for(Lab::MetaStackReading::TWIN_SWEEP))

    # Final once this sweep and the logic sweep, whose children are its twins, have settled.
    def self.final?(experiment)
      twins = twin_experiment
      !twins.nil? && DescendantSweepSettledService.call(experiment) && DescendantSweepSettledService.call(twins)
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::MetaStackReading::Report.new(children: children, arms: arms, tests: tests,
                                        kept_tests: tests(keep_extinct: true), unpiloted_tests: tests(unpiloted: true),
                                        final: self.class.final?(@experiment))
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
    # without the pairs of Lab::MetaStackReading::PILOT_PARENTS.
    def tests(keep_extinct: false, unpiloted: false)
      suffix = if keep_extinct then Lab::MetaStackReading::KEPT_SUFFIX
               elsif unpiloted then Lab::MetaStackReading::UNPILOTED_SUFFIX
               end

      Lab::MetaStackReading::HYPOTHESES.map do |hypothesis, (key, treated_key, control_key)|
        treated = arm(treated_key)
        control = arm(control_key)
        twins = control.children.index_by { |child| [child.parent_id, child.seed] }
        pairs = treated.children.reject { |child| unpiloted && piloted?(child) }
                       .map { |child| pair(key, keep_extinct, child, twins[[child.parent_id, child.seed]]) }
        Lab::LogicReading::Test.new(hypothesis: "#{hypothesis}#{suffix}", treatment: treated.treatment,
                                    control: control.treatment,
                                    comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false))
      end
    end

    def piloted?(child) = Lab::MetaStackReading::PILOT_PARENTS.include?(child.parent_id)

    def pair(key, keep_extinct, treated, control)
      Lab::LogicReading::Pairs::Capability.new(key: key, keep_extinct: keep_extinct, parent_id: treated.parent_id,
                                               seed: treated.seed, treated: treated, control: control)
    end

    def children
      @children ||= (own_runs + twin_runs).filter_map do |run|
        treatment = treatment_of(run)
        next if treatment.nil?

        ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment,
                     status: run.status, **logic_child_reading(run))
      end
    end

    def treatment_of(run)
      key = Lab::MetaStackReading.treatment_key(run.params)
      TREATMENTS.find { |treatment| treatment.key == key }
    end

    def own_runs
      descendant_runs(@experiment).reject { |run| twin?(run) }
    end

    # The logic sweep's children of the twin arms only: its deep-only arm is read nowhere here.
    def twin_runs
      twins = self.class.twin_experiment
      twins.nil? ? [] : descendant_runs(twins).select { |run| twin?(run) }
    end

    def twin?(run) = Lab::MetaStackReading::TWIN_ARMS.include?(Lab::MetaStackReading.treatment_key(run.params))
  end
end
