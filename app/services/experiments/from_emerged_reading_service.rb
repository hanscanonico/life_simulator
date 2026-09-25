# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the from-emerged sweep (`docs/design_record.md`,
  # 2026-09-25, "Runs that start from an emerged world"): each child read over its own
  # samples (Lab::DescendantReading::Child), each treatment counted, each treated arm read
  # against the continuation over paired (parent, seed) children
  # (Lab::DescendantReading::Comparison), and the continuation read for persistence. It is
  # interim until every candidate parent is terminal and read, and every child of every
  # qualifying parent has finished.
  #
  # It reads stored samples and changes nothing.
  class FromEmergedReadingService
    include Callable

    SAMPLE_KEYS = [Lab::DescendantReading::SHARE_KEY, Lab::DescendantReading::REPLICATING_KEY,
                   Lab::DescendantReading::COMPLEXITY_KEY, *Lab::DescendantReading::DESCRIPTIVE_KEYS].freeze

    Treatment = Data.define(:name, :bundle) do
      def continuation? = bundle.empty?

      def priced? = bundle.fetch("steal_amount", 0).to_i.positive?

      def hypothesis = bundle.key?("interaction") ? "H-host" : "H-economy"
    end

    # `relapse_colony_age` and `watched_colony_ages` are Run#colony_age_at, counted from the
    # parent's emergence; nil where the parent has none.
    ChildRow = Data.define(:run_id, :parent_id, :seed, :treatment, :status, :reading, :relapse_colony_age,
                           :watched_colony_ages) do
      def finished? = status == "finished"

      def cells
        [run_id, parent_id, seed, treatment.name, status, reading.persistence, reading.relapse_epoch,
         relapse_colony_age, watched_colony_ages&.join("–"), reading.complexity, reading.first_instructions,
         reading.last_instructions]
      end
    end

    # H-persistence over the continuation children read for persistence.
    Persistence = Data.define(:children) do
      def relapsed = children.select { |child| child.reading.persistence == :relapsed }

      def refuted? = relapsed.any?

      def outcome
        return :no_children if children.empty?

        refuted? ? :refuted : :held
      end

      def outcome_label = outcome.to_s.tr("_", " ")

      # The span of colony ages the continuation children were watched over, the ages a
      # relapse is listed beside. A child whose parent has no emergence epoch has no colony
      # age and is left out of it.
      def watched_colony_ages
        spans = children.filter_map(&:watched_colony_ages)
        spans.empty? ? nil : [spans.map(&:first).min, spans.map(&:last).max]
      end

      def badge_class = { held: "badge-success", refuted: "badge-error" }.fetch(outcome, "badge-info")
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::DescendantReading::Report.new(children: children, arms: arms, comparisons: comparisons,
                                         persistence: persistence,
                                         final: DescendantSweepSettledService.call(experiment))
    end

    private

    attr_reader :experiment

    def arms
      @arms ||= treatments.map do |treatment|
        Lab::DescendantReading::Arm.new(treatment: treatment, children: children_of(treatment))
      end
    end

    def comparisons
      control = arms.find { |arm| arm.treatment.continuation? }
      return {} if control.nil?

      arms.reject { |arm| arm.equal?(control) }.to_h { |arm| [arm.treatment, comparison(arm, control)] }
    end

    def comparison(arm, control)
      controls = control.children.index_by { |child| [child.parent_id, child.seed] }
      pairs = arm.children.map do |child|
        Lab::DescendantReading::Comparison::Pair.new(parent_id: child.parent_id, seed: child.seed,
                                                     treated: child.reading,
                                                     control: controls[[child.parent_id, child.seed]]&.reading)
      end
      Lab::DescendantReading::Comparison.new(pairs: pairs, kills: relapses_more?(arm, control))
    end

    def relapses_more?(arm, control)
      treated = arm.relapse_rate
      baseline = control.relapse_rate
      !treated.nil? && !baseline.nil? && treated > baseline
    end

    def persistence
      control = arms.find { |arm| arm.treatment.continuation? }
      Persistence.new(children: control ? control.children.select { |child| child.reading.persistence } : [])
    end

    def children_of(treatment) = children.select { |child| child.treatment == treatment }

    def children
      @children ||= child_runs.map { |run| child_row(run, read(run)) }
    end

    def child_row(run, reading)
      ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment_of(run),
                   status: run.status, reading: reading,
                   relapse_colony_age: reading.relapse_epoch && run.colony_age_at(reading.relapse_epoch),
                   watched_colony_ages: watched_colony_ages(run, reading))
    end

    # The colony ages a child was watched over, from its parent epoch to its last sample.
    def watched_colony_ages(run, reading)
      return nil unless run.emerged? && reading.sampled?

      [run.colony_age_at(run.parent_epoch), run.colony_age_at(reading.last_epoch)]
    end

    def read(run)
      Lab::DescendantReading::Child.read(own_samples(run), parent_epoch: run.parent_epoch,
                                                           descriptive: Lab::DescendantReading::DESCRIPTIVE_KEYS,
                                                           bin: Lab::DescendantReading::TRAJECTORY_BIN)
    end

    def child_runs
      @child_runs ||= experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed, :id)
                                .select(:id, :parent_run_id, :parent_epoch, :seed, :params, :status,
                                        :emergence_epoch).to_a
    end

    # One child's samples at a time, and of each only the keys read here: the sweep's
    # samples held at once are what cost the app container its memory on the host-parasite
    # sweep (issue #223).
    def own_samples(run)
      run.samples.where("epoch > ?", run.parent_epoch).order(:epoch).pluck(:epoch, observed_values)
    end

    def observed_values
      @observed_values ||= Arel.sql(ActiveRecord::Base.sanitize_sql_array(
        ["jsonb_build_object(#{(['?, samples.values -> ?'] * SAMPLE_KEYS.size).join(', ')})",
         *SAMPLE_KEYS.flat_map { |key| [key, key] }]
      ))
    end

    def axis = @axis ||= Axis.sweep(experiment.param_grid).first

    def treatments
      @treatments ||= (axis ? axis.values : [{}]).map { |bundle| Treatment.new(name: name_of(bundle), bundle: bundle) }
    end

    def treatment_of(run)
      bundle = axis ? axis.value_of(run.params) : {}
      treatments.find { |treatment| treatment.bundle == bundle } || treatments.first
    end

    # The treatments named for what they do, where the grid's own label would print a
    # bundle's values ("2048×1024×32768×0.5").
    def name_of(bundle)
      return "continuation" if bundle.empty?
      return "#{bundle['interaction']} mode" if bundle.key?("interaction")
      return "economy #{bundle['energy_influx']}" if bundle.key?("energy_influx")

      axis.label_of(bundle)
    end
  end
end
