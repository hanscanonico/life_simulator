# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the out-compute sweep (`docs/design_record.md`, 2026-10-03,
  # "Out-compute: does an endogenous rule make computing climb, and keep climbing, with nothing
  # paid?"): each child's own samples under the topless-rise entry's rules, unchanged — the
  # settling window, extinction and settled relapse (Lab::DescendantReading::Child,
  # Lab::FromEmergedHeldout::Child) and the rise rule (Lab::ToplessRiseReading::Child), here on
  # `logic_depth_max` and again on `logic_depth_classes`. Its arm is keyed on the predation
  # relation (Lab::OutComputeReading.treatment_key). The five tests are sign tests of the
  # out-compute arm against the none, equal and shadow children of the same parent, each read
  # again with the extinct pairs kept and without the piloted parents. It is interim until the
  # parent pool and every child have settled.
  #
  # It reads stored samples, one child at a time, and changes nothing.
  class OutComputeReadingService
    include Callable
    include ReadsLogicChildren

    SAMPLE_KEYS = [
      Lab::OutComputeReading::SHARE_KEY, Lab::OutComputeReading::DEPTH_KEY, Lab::OutComputeReading::CLASSES_KEY,
      *Lab::OutComputeReading::DESCRIPTIVE_KEYS
    ].freeze

    Treatment = LogicReadingService::Treatment

    TREATMENTS = Lab::OutComputeReading::TREATMENT_NAMES.map { |key, name| Treatment.new(key: key, name: name) }.freeze

    # `share` is the from-emerged rule's reading of the settled samples (the replicator share
    # and the descriptive medians), `heldout` the extinction and relapse rules, `depth` and
    # `classes` the rise rule on the two keys.
    ChildRow = Data.define(:run_id, :parent_id, :seed, :treatment, :status, :share, :heldout, :depth,
                           :classes) do
      delegate :rises?, :ceilinged?, to: :depth

      def finished? = status == "finished"

      def settled_relapse? = !heldout.settled_relapse_epoch.nil?

      def extinct? = heldout.extinct == true

      def reached_floor? = depth.reached_floor

      def classes_rise? = classes.rises?

      # The last-decile median depth the level tests compare.
      def level = depth.last_depth

      # Read and carrying the last decile's depth; not extinct unless `keep_extinct`.
      def level_measured?(keep_extinct: false) = counted?(keep_extinct) && !level.nil?

      # Read and carrying both deciles of the `reading` (:depth or :classes); not extinct
      # unless `keep_extinct`.
      def rise_measured?(reading, keep_extinct: false) = counted?(keep_extinct) && public_send(reading).measured?

      def cells
        [run_id, parent_id, seed, treatment.name, status, heldout.settled_relapse_epoch, heldout.extinct,
         *depth_cells, *classes_cells, *Lab::OutComputeReading::DESCRIPTIVE_KEYS.map { |key| share.last_median(key) },
         share.last_share]
      end

      private

      def counted?(keep_extinct) = heldout.read && (keep_extinct || !heldout.extinct)

      def depth_cells
        [depth.descent_depth, depth.first_half_held, depth.fifth_depth, depth.bar, depth.last_depth, rises?,
         ceilinged?, depth.deepest_held, depth.deepest_held_epoch, depth.late_depths.join(" ").presence,
         reached_floor?]
      end

      def classes_cells = [classes.descent_depth, classes.bar, classes.last_depth, classes_rise?]
    end

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("out_compute")

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::OutComputeReading::Report.new(children: children, arms: arms, tests: tests,
                                         kept_tests: tests(keep_extinct: true), unpiloted_tests: tests(unpiloted: true),
                                         final: DescendantSweepSettledService.call(@experiment))
    end

    private

    def arms
      @arms ||= TREATMENTS.map do |treatment|
        Lab::OutComputeReading::Arm.new(treatment: treatment,
                                        children: children.select { |child| child.treatment == treatment })
      end
    end

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    # `keep_extinct` re-reads each test with the pairs of extinct children kept; `unpiloted`
    # without the pairs of Lab::OutComputeReading::PILOT_PARENTS.
    def tests(keep_extinct: false, unpiloted: false)
      suffix = if keep_extinct then Lab::OutComputeReading::KEPT_SUFFIX
               elsif unpiloted then Lab::OutComputeReading::UNPILOTED_SUFFIX
               end

      Lab::OutComputeReading::HYPOTHESES.map do |hypothesis, (treated_key, control_key, reading)|
        treated = arm(treated_key)
        control = arm(control_key)
        twins = control.children.index_by { |child| [child.parent_id, child.seed] }
        pairs = treated.children.reject { |child| unpiloted && piloted?(child) }.map do |child|
          pair(reading, keep_extinct, child, twins[[child.parent_id, child.seed]])
        end
        Lab::LogicReading::Test.new(hypothesis: "#{hypothesis}#{suffix}", treatment: treated.treatment,
                                    control: control.treatment,
                                    comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false))
      end
    end

    def piloted?(child) = Lab::OutComputeReading::PILOT_PARENTS.include?(child.parent_id)

    def pair(reading, keep_extinct, treated, control)
      attributes = { keep_extinct: keep_extinct, parent_id: treated.parent_id, seed: treated.seed, treated: treated,
                     control: control }
      return Lab::OutComputeReading::Pairs::Level.new(**attributes) if reading == :level

      Lab::OutComputeReading::Pairs::Rise.new(reading: reading, **attributes)
    end

    def children
      @children ||= descendant_runs(@experiment).filter_map { |run| child_row(run) }
    end

    def child_row(run)
      treatment = treatment_of(run)
      return nil if treatment.nil?

      samples = own_samples(run)
      settled = samples.select { |epoch, _| epoch > run.parent_epoch + Lab::OutComputeReading::SETTLING_WINDOW }
      share = Lab::DescendantReading::Child.read(settled, parent_epoch: run.parent_epoch,
                                                          descriptive: Lab::OutComputeReading::DESCRIPTIVE_KEYS)
      ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment,
                   status: run.status, share: share,
                   heldout: Lab::FromEmergedHeldout::Child.read(samples, parent_epoch: run.parent_epoch,
                                                                         last_share: share.last_share),
                   depth: Lab::ToplessRiseReading::Child.read(samples, parent_epoch: run.parent_epoch),
                   classes: Lab::ToplessRiseReading::Child.read(samples, parent_epoch: run.parent_epoch,
                                                                         key: Lab::OutComputeReading::CLASSES_KEY,
                                                                         ceiling: nil))
    end

    def treatment_of(run)
      key = Lab::OutComputeReading.treatment_key(run.params)
      TREATMENTS.find { |treatment| treatment.key == key }
    end
  end
end
