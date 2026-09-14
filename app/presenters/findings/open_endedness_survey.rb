# frozen_string_literal: true

module Findings
  # The three substrate bets of DESIGN §1.3 — instruction cost (sweep 6), environmental
  # structure (sweep 7) and room to grow (sweep 8) — read as one open-endedness question:
  # after emergence, does the dominant replicator's complexity, or the number of lineages
  # a world keeps, go anywhere the default substrate did not take it?
  #
  # Each sweep carries its own control: the first arm of its grid is the substrate every
  # earlier sweep ran — the cost off, a uniform world, a tape that cannot lengthen — so a
  # treated arm is read against the default substrate inside the same experiment and never
  # across sweeps. Nothing is fitted: a run's plateau is placed above or below its control
  # arm's median and the directions are counted, the way `ComplexitySurvey` counts them.
  class OpenEndednessSurvey
    # Below this many measured runs an arm decides nothing, and the hypothesis it belongs
    # to reads unresolved rather than resting on a single seed.
    MIN_ARM_RUNS = 2

    # The two observables of DESIGN §1.2 this reads, by the name a sample stores them
    # under. The aggregate is spelled out per observable below rather than built from the
    # name: no SQL on this page is assembled from a variable.
    OBSERVABLES = { length: "dominant_compressed_len", lineages: "distinct_lineages" }.freeze

    LENGTH_READING = Arel.sql(
      "CASE WHEN jsonb_typeof(samples.values -> 'dominant_compressed_len') = 'number' " \
      "THEN (samples.values ->> 'dominant_compressed_len')::numeric END"
    )

    LINEAGE_READING = Arel.sql(
      "CASE WHEN jsonb_typeof(samples.values -> 'distinct_lineages') = 'number' " \
      "THEN (samples.values ->> 'distinct_lineages')::numeric END"
    )

    VERDICT_BADGES = { supported: "badge-success", not_supported: "badge-error",
                       unresolved: "badge-info" }.freeze

    # The sweeps in DESIGN order, each with the reading its hypothesis turns on: sweeps 7
    # and 8 both predict a higher complexity plateau, sweep 6 predicts a second niche,
    # which this substrate reads as lineages kept alive.
    BETS = [
      { sweep: "energy_per_epoch", decided_by: :lineages },
      { sweep: "environmental_structure", decided_by: :length },
      { sweep: "max_tape_len", decided_by: :length }
    ].freeze

    # One transitioned run, as the two series its samples carry at or after its crossing.
    Reading = Data.define(:run, :series) do
      delegate :seed, :transition_epoch, to: :run

      def readings(observable) = points(observable).size

      def measured?(observable) = points(observable).any?

      def plateau(observable) = points(observable).map(&:last).max

      def first_of(observable) = points(observable).first&.last

      def last_of(observable) = points(observable).last&.last

      # Two readings or it went nowhere that can be told: a single sample is unread, not
      # flat.
      def rising?(observable)
        readings(observable) >= 2 && last_of(observable) > first_of(observable)
      end

      def points(observable) = series.fetch(observable, [])
    end

    # One arm of a sweep: the runs of that grid value that transitioned and were measured.
    Arm = Data.define(:value, :label, :control, :readings) do
      def control? = control

      def measured(observable) = readings.select { |reading| reading.measured?(observable) }

      def measured_count(observable) = measured(observable).size

      def rising_count(observable) = measured(observable).count { |reading| reading.rising?(observable) }

      def plateaus(observable) = measured(observable).map { |reading| reading.plateau(observable) }

      def median_plateau(observable) = OpenEndednessSurvey.median(plateaus(observable))

      def above_count(observable, threshold)
        return 0 if threshold.nil?

        plateaus(observable).count { |plateau| plateau > threshold }
      end

      def comparable?(observable) = measured_count(observable) >= MIN_ARM_RUNS

      def transitioned_count = readings.size
    end

    # One hypothesis: a sweep, its arms and the verdict its own runs support.
    Bet = Data.define(:slug, :experiment, :axis, :arms, :decided_by) do
      def experiment? = experiment.present?

      def control_arm = arms.find(&:control?)

      def treated_arms = arms.reject(&:control?)

      def comparable_arms = treated_arms.select { |arm| arm.comparable?(decided_by) }

      def control_median = control_arm&.median_plateau(decided_by)

      # A control arm that says nothing cannot be raised above, and neither can a treated
      # arm that has not been run: either way the hypothesis is untested, not refuted.
      def resolved? = control_arm&.comparable?(decided_by).present? && comparable_arms.any?

      # An arm raises the plateau when most of its runs settle strictly above the median
      # of the control arm's runs. A majority, not a mean: the reading is a count.
      def raises?(arm) = arm.above_count(decided_by, control_median) * 2 > arm.measured_count(decided_by)

      def raising_arms = resolved? ? comparable_arms.select { |arm| raises?(arm) } : []

      def verdict
        return :unresolved unless resolved?

        raising_arms.any? ? :supported : :not_supported
      end

      def verdict_label = verdict.to_s.tr("_", " ")

      def badge_class = VERDICT_BADGES.fetch(verdict)

      def measured_count = measured_count_of(decided_by)

      def transitioned_count = arms.sum(&:transitioned_count)

      def rising_count_of(observable) = arms.sum { |arm| arm.rising_count(observable) }

      def measured_count_of(observable) = arms.sum { |arm| arm.measured_count(observable) }
    end

    def self.build = new

    # The median of a sorted list, averaging the middle pair on an even count: one number
    # standing for an arm, chosen so one runaway seed cannot carry it.
    def self.median(values)
      return nil if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
    end

    def bets = @bets ||= BETS.map { |bet| build_bet(bet.fetch(:sweep), bet.fetch(:decided_by)) }

    def bet(slug) = bets.find { |bet| bet.slug == slug }

    def experiments = bets.filter_map(&:experiment)

    def any? = bets.any? { |bet| bet.transitioned_count.positive? }

    def resolved_bets = bets.select(&:resolved?)

    def supported_bets = bets.select { |bet| bet.verdict == :supported }

    def unresolved_bets = bets.select { |bet| bet.verdict == :unresolved }

    def transitioned_count = bets.sum(&:transitioned_count)

    def rising_count(observable) = bets.sum { |bet| bet.rising_count_of(observable) }

    def measured_count(observable) = bets.sum { |bet| bet.measured_count_of(observable) }

    private

    def build_bet(sweep, decided_by)
      slug = Lab.slug_for(sweep)
      axis = Experiments::Axis.sweep(Lab::SWEEPS.fetch(sweep).fetch(:param_grid)).first
      experiment = experiments_by_slug[slug]

      Bet.new(slug: slug, experiment: experiment, axis: axis, decided_by: decided_by,
              arms: arms_of(axis, runs_by_experiment.fetch(experiment&.id, [])))
    end

    # The control is the first value of the grid — the substrate every earlier sweep ran,
    # as `Lab::SWEEPS` states for each of the three — so the sweep table stays the one
    # place that says which arm is off.
    def arms_of(axis, runs)
      axis.values.map do |value|
        arm_runs = runs.select { |run| axis.matches?(run.params, value) }

        Arm.new(value: value, label: axis.label_of(value), control: value == axis.values.first,
                readings: arm_runs.map { |run| Reading.new(run: run, series: series_by_run.fetch(run.id, {})) })
      end
    end

    def experiments_by_slug
      @experiments_by_slug ||= Experiment.where(slug: BETS.map { |bet| Lab.slug_for(bet.fetch(:sweep)) })
                                         .index_by(&:slug)
    end

    def runs_by_experiment
      @runs_by_experiment ||= Run.transitioned.where(experiment_id: experiments_by_slug.values.map(&:id))
                                 .order(:transition_epoch, :id).to_a.group_by(&:experiment_id)
    end

    def transitioned_runs = runs_by_experiment.values.flatten

    # One query for the whole page, both observables at once: the two readings are written
    # into the same sample, and a sample the engine reported a null for — no tested tape
    # replicated — drops out of that observable's series while staying in the other's.
    def series_by_run
      @series_by_run ||=
        Sample.joins(:run).where(run_id: transitioned_runs.map(&:id))
              .where("samples.epoch >= runs.transition_epoch")
              .order(:run_id, :epoch)
              .pluck(:run_id, :epoch, LENGTH_READING, LINEAGE_READING)
              .group_by(&:first)
              .transform_values { |rows| series_of(rows) }
    end

    def series_of(rows)
      { length: points_of(rows) { |row| row[2] }, lineages: points_of(rows) { |row| row[3] } }
    end

    def points_of(rows)
      rows.filter_map do |row|
        reading = yield(row)
        [row[1], reading.to_i] if reading
      end
    end
  end
end
