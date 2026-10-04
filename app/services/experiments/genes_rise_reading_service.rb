# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the genes-rise sweep (`docs/design_record.md`, 2026-10-04,
  # "Genes rise: does held code keep rising late, at a cap the run does not reach, with nothing
  # paid?"): each child's own samples under the topless-rise entry's rules — the settling
  # window, extinction and settled relapse (Lab::DescendantReading::Child,
  # Lab::FromEmergedHeldout::Child) and the rise rule (Lab::ToplessRiseReading::Child) — with
  # the study's persistent new maxima and a magnitude on top (Lab::GenesRiseReading::Series),
  # on `logic_depth_classes` and on `genes_essential_held`; the final-quarter gain
  # (Lab::GenesRiseReading::Room); and McShea's minimum where its offline reading is handed in
  # as `minima`, by run id (Lab::GenesRiseReading::Minimum). Its arm is keyed on the relation
  # and the cap (Lab::GenesRiseReading.treatment_key). The five tests are sign tests of the
  # count arm against the drift, capped and shadow children of the same parent, each read
  # again with the extinct pairs kept. It is interim until the parent pool and every child have
  # settled.
  #
  # It reads stored samples, one child at a time, and changes nothing.
  class GenesRiseReadingService
    include Callable
    include ReadsLogicChildren

    SAMPLE_KEYS = [
      Lab::GenesRiseReading::SHARE_KEY, Lab::GenesRiseReading::CLASSES_KEY, Lab::GenesRiseReading::GENES_KEY,
      *Lab::GenesRiseReading::DESCRIPTIVE_KEYS
    ].freeze

    Treatment = LogicReadingService::Treatment

    TREATMENTS = Lab::GenesRiseReading::TREATMENT_NAMES.map { |key, name| Treatment.new(key: key, name: name) }.freeze

    # `share` is the from-emerged rule's reading of the settled samples (the replicator share
    # and the descriptive medians), `heldout` the extinction and relapse rules, `classes` and
    # `genes` the late-rise readings of the two keys, `room` the final-quarter gain, `minimum`
    # the offline minimum, `cap` the channel's and `fifth_length` the fifth-decile median mean
    # length.
    ChildRow = Data.define(:run_id, :parent_id, :seed, :treatment, :status, :cap, :fifth_length, :share, :heldout,
                           :classes, :genes, :room, :minimum) do
      def finished? = status == "finished"

      def settled_relapse? = !heldout.settled_relapse_epoch.nil?

      def extinct? = heldout.extinct == true

      # Read and carrying the `reading` (:classes, :genes, :room or :minimum); not extinct
      # unless `keep_extinct`.
      def measured?(reading, keep_extinct: false) = counted?(keep_extinct) && public_send(reading).measured?

      def classes_measured? = measured?(:classes)

      def room_measured? = measured?(:room)

      delegate :late_rise?, to: :classes, prefix: true
      delegate :late_rise?, to: :genes, prefix: true
      delegate :late_rise?, to: :minimum, prefix: true

      def length = share.last_median(Lab::GenesRiseReading::LENGTH_KEY)

      # The last-decile median mean length at NEAR_CAP_SHARE of the cap or past it.
      def near_cap? = !length.nil? && !cap.nil? && length >= cap * Lab::GenesRiseReading::NEAR_CAP_SHARE

      def cells
        [run_id, parent_id, seed, treatment.name, status, heldout.settled_relapse_epoch, heldout.extinct,
         *series_cells(classes), *series_cells(genes), *room_cells, *descriptive_cells, share.last_share]
      end

      private

      def counted?(keep_extinct) = heldout.read && (keep_extinct || !heldout.extinct)

      def room_cells
        [classes.final_quarter_epoch, room.first, room.last, room.gain, minimum.fifth, minimum.last,
         minimum.late_rise?]
      end

      def series_cells(series)
        [series.descent_depth, series.bar, series.last, series.rises?, series.maxima.size, series.last_maximum_epoch,
         series.late_rise?]
      end

      def descriptive_cells
        [share.last_median("logic_depth_max"), length, near_cap?,
         per_length(classes.rise.fifth_depth, fifth_length, 1000), per_length(classes.last, length, 1000),
         per_length(genes.last, length, Lab::GenesRiseReading::GENE_LENGTH),
         *%w[fidelity_p10 fidelity_p50 fidelity_p90 repertoire_mean silent_share predation_rate
             predation_relation_rate].map { |key| share.last_median(key) }]
      end

      # `count` per `bytes` of a decile's median mean `length`: classes per 1 000 bytes,
      # essential genes per gene.
      def per_length(count, length, bytes)
        return nil if count.nil? || length.nil? || length.zero?

        (count * bytes / length.to_f).round(3)
      end
    end

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("genes_rise")

    # `minima`: the offline minimum of each child, by run id (Lab::GenesRiseReading::Minimum);
    # nil until the offline reading exists.
    def initialize(experiment:, minima: nil)
      @experiment = experiment
      @minima = minima
    end

    def call
      Lab::GenesRiseReading::Report.new(children: children, arms: arms, tests: tests,
                                        kept_tests: tests(keep_extinct: true), minima_read: !@minima.nil?,
                                        final: DescendantSweepSettledService.call(@experiment))
    end

    private

    def arms
      @arms ||= TREATMENTS.map do |treatment|
        Lab::GenesRiseReading::Arm.new(treatment: treatment,
                                       children: children.select { |child| child.treatment == treatment })
      end
    end

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    def tests(keep_extinct: false)
      suffix = keep_extinct ? Lab::GenesRiseReading::KEPT_SUFFIX : nil
      Lab::GenesRiseReading::HYPOTHESES.map do |hypothesis, (treated_key, control_key, reading)|
        treated = arm(treated_key)
        control = arm(control_key)
        twins = control.children.index_by { |child| [child.parent_id, child.seed] }
        pairs = treated.children.map do |child|
          pair(reading, keep_extinct, child, twins[[child.parent_id, child.seed]])
        end
        Lab::LogicReading::Test.new(hypothesis: "#{hypothesis}#{suffix}", treatment: treated.treatment,
                                    control: control.treatment,
                                    comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false))
      end
    end

    def pair(reading, keep_extinct, treated, control)
      attributes = { keep_extinct: keep_extinct, parent_id: treated.parent_id, seed: treated.seed, treated: treated,
                     control: control }
      return Lab::GenesRiseReading::Pairs::Room.new(**attributes) if reading == :room

      Lab::GenesRiseReading::Pairs::LateRise.new(reading: reading, **attributes)
    end

    def children
      @children ||= descendant_runs(@experiment).filter_map { |run| child_row(run) }
    end

    def child_row(run)
      treatment = treatment_of(run)
      return nil if treatment.nil?

      samples = own_samples(run)
      settled = samples.select { |epoch, _| epoch > run.parent_epoch + Lab::GenesRiseReading::SETTLING_WINDOW }
      share = Lab::DescendantReading::Child.read(settled, parent_epoch: run.parent_epoch,
                                                          descriptive: Lab::GenesRiseReading::DESCRIPTIVE_KEYS)
      ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment,
                   status: run.status, cap: run.params["meta_max_len"], fifth_length: fifth_length(settled),
                   share: share,
                   heldout: Lab::FromEmergedHeldout::Child.read(samples, parent_epoch: run.parent_epoch,
                                                                         last_share: share.last_share),
                   classes: series(samples, run, Lab::GenesRiseReading::CLASSES_KEY),
                   genes: series(samples, run, Lab::GenesRiseReading::GENES_KEY),
                   room: Lab::GenesRiseReading::Room.read(samples, parent_epoch: run.parent_epoch),
                   minimum: @minima&.fetch(run.id, nil) || Lab::GenesRiseReading::Minimum.none)
    end

    # The fifth decile cut by index over the settled samples, as the rise rule cuts it, and the
    # lower median of its mean lengths.
    def fifth_length(settled)
      decile = Lab::ToplessRiseReading::RISE_DECILE
      size = settled.size
      lengths = settled[((decile - 1) * size / Lab::GenesRiseReading::DECILES)...(decile * size / Lab::GenesRiseReading::DECILES)]
                .filter_map { |_, values| values[Lab::GenesRiseReading::LENGTH_KEY] }.grep(Numeric)
      lengths.size < Lab::GenesRiseReading::MIN_DECILE_SAMPLES ? nil : Findings::Median.of(lengths)
    end

    def series(samples, run, key)
      Lab::GenesRiseReading::Series.read(samples, parent_epoch: run.parent_epoch, key: key)
    end

    def treatment_of(run)
      key = Lab::GenesRiseReading.treatment_key(run.params)
      TREATMENTS.find { |treatment| treatment.key == key }
    end
  end
end
