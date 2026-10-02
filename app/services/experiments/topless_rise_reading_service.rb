# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the topless-rise sweep (`docs/design_record.md`,
  # 2026-10-02, "Topless rise: does the deepest rung held keep rising when depth is paid?"):
  # each child's own samples under the logic entry's settling window, extinction and
  # settled-relapse rules (Lab::DescendantReading::Child, Lab::FromEmergedHeldout::Child),
  # and the rise rule on `logic_depth_max` (Lab::ToplessRiseReading::Child). Its arm is keyed
  # on its reward and `task_depth_cap` (Lab::ToplessRiseReading.treatment_key). H-rise and
  # H-rise-paid are sign tests of the rise arm against the none and capped children of the
  # same parent, each read again with the extinct pairs kept and on the deep parents'
  # children alone. It is interim until the parent pool and every child have settled.
  #
  # It reads stored samples, one child at a time, and changes nothing.
  class ToplessRiseReadingService
    include Callable
    include ReadsLogicChildren

    SAMPLE_KEYS = [
      Lab::DescendantReading::SHARE_KEY, Lab::ToplessRiseReading::DEPTH_KEY, Lab::ToplessRiseReading::CLASSES_KEY
    ].freeze

    Treatment = LogicReadingService::Treatment

    TREATMENTS = Lab::ToplessRiseReading::TREATMENT_NAMES.map { |key, name| Treatment.new(key: key, name: name) }.freeze

    # `share` is the from-emerged rule's reading of the replicator share over the settled
    # samples, `heldout` the extinction and relapse rules, `depth` the rise rule.
    ChildRow = Data.define(:run_id, :parent_id, :seed, :treatment, :status, :share, :heldout, :depth) do
      delegate :rises?, :ceilinged?, to: :depth

      def finished? = status == "finished"

      def settled_relapse? = !heldout.settled_relapse_epoch.nil?

      def extinct? = heldout.extinct == true

      def deep_parent? = Lab::ToplessRiseReading::DEEP_PARENTS.include?(parent_id)

      def reached_floor? = depth.reached_floor

      # Read and carrying both deciles' depth; not extinct unless `keep_extinct`.
      def rise_measured?(keep_extinct: false)
        heldout.read && (keep_extinct || !heldout.extinct) && depth.measured?
      end

      def cells
        [run_id, parent_id, seed, treatment.name, status, deep_parent?, heldout.settled_relapse_epoch, heldout.extinct,
         depth.fifth_depth, depth.last_depth, rises?, ceilinged?, depth.deepest_held, depth.deepest_held_epoch,
         depth.late_depths.join(" ").presence, reached_floor?, depth.last_classes, share.last_share]
      end
    end

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("topless_rise")

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::ToplessRiseReading::Report.new(children: children, arms: arms, tests: tests,
                                          kept_tests: tests(keep_extinct: true), deep_tests: tests(deep: true),
                                          final: DescendantSweepSettledService.call(@experiment))
    end

    private

    def arms
      @arms ||= TREATMENTS.map do |treatment|
        Lab::ToplessRiseReading::Arm.new(treatment: treatment,
                                         children: children.select { |child| child.treatment == treatment })
      end
    end

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    # `keep_extinct` re-reads each test with the pairs of extinct children kept; `deep` on the
    # pairs of Lab::ToplessRiseReading::DEEP_PARENTS alone.
    def tests(keep_extinct: false, deep: false)
      suffix = if keep_extinct then Lab::ToplessRiseReading::KEPT_SUFFIX
               elsif deep then Lab::ToplessRiseReading::DEEP_SUFFIX
               end

      Lab::ToplessRiseReading::HYPOTHESES.map do |hypothesis, (treated_key, control_key)|
        treated = arm(treated_key)
        control = arm(control_key)
        twins = control.children.index_by { |child| [child.parent_id, child.seed] }
        pairs = treated.children.select { |child| !deep || child.deep_parent? }
                       .map { |child| pair(keep_extinct, child, twins[[child.parent_id, child.seed]]) }
        Lab::LogicReading::Test.new(hypothesis: "#{hypothesis}#{suffix}", treatment: treated.treatment,
                                    control: control.treatment,
                                    comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false))
      end
    end

    def pair(keep_extinct, treated, control)
      Lab::ToplessRiseReading::Pair.new(keep_extinct: keep_extinct, parent_id: treated.parent_id, seed: treated.seed,
                                        treated: treated, control: control)
    end

    def children
      @children ||= descendant_runs(@experiment).map { |run| child_row(run) }
    end

    def child_row(run)
      samples = own_samples(run)
      settled = samples.select { |epoch, _| epoch > run.parent_epoch + Lab::ToplessRiseReading::SETTLING_WINDOW }
      share = Lab::DescendantReading::Child.read(settled, parent_epoch: run.parent_epoch)
      ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment_of(run),
                   status: run.status, share: share,
                   heldout: Lab::FromEmergedHeldout::Child.read(samples, parent_epoch: run.parent_epoch,
                                                                         last_share: share.last_share),
                   depth: Lab::ToplessRiseReading::Child.read(samples, parent_epoch: run.parent_epoch))
    end

    def treatment_of(run)
      key = Lab::ToplessRiseReading.treatment_key(run.params)
      TREATMENTS.find { |treatment| treatment.key == key }
    end
  end
end
