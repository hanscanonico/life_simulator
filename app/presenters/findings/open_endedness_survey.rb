# frozen_string_literal: true

module Findings
  # The three substrate bets of DESIGN §1.3 — instruction cost (sweep 6), environmental
  # structure (sweep 7) and room to grow (sweep 8) — read as one open-endedness question:
  # after emergence, does the dominant replicator's complexity, or the number of lineages
  # a world keeps, go anywhere the default substrate did not take it?
  #
  # Emergence here is the confirmed crossing (`docs/design_record.md`, 2026-09-15): a run
  # the detector flagged but no replicator or copy backed is not one of these worlds, and
  # every reading below is taken at or after `emergence_epoch`.
  #
  # Each sweep carries its own control: the first arm of its grid is the substrate every
  # earlier sweep ran — the cost off, a uniform world, a tape that cannot lengthen — so a
  # treated arm is read against the default substrate inside the same experiment and never
  # across sweeps. Nothing is fitted: a run's peak is placed above or below its control
  # arm's median and the directions are counted, the way `ComplexitySurvey` counts them.
  class OpenEndednessSurvey
    # Below this many measured runs an arm decides nothing, and the hypothesis it belongs
    # to reads unresolved rather than resting on a single seed.
    MIN_ARM_RUNS = 2

    # An arm nobody ran and an arm that was run to the end and stayed empty are not the
    # same silence. At or above this many terminal runs with nothing emerged in any of them
    # the arm has drawn a whole seed-block blank — the block DESIGN §1.3 budgets per arm —
    # and it is read rather than unseeded (`docs/design_record.md`, 2026-09-15).
    MIN_BARREN_RUNS = 10

    # Both observables are read out of the same jsonb column with the same guard, so the
    # expression is written once and bound to the key rather than spelled out twice.
    def self.numeric_reading(key)
      Arel.sql(
        ApplicationRecord.sanitize_sql_array(
          ["CASE WHEN jsonb_typeof(samples.values -> ?) = 'number' " \
           "THEN (samples.values ->> ?)::numeric END", key, key]
        )
      )
    end
    private_class_method :numeric_reading

    LENGTH_READING = numeric_reading("dominant_compressed_len")
    LINEAGE_READING = numeric_reading("distinct_lineages")

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

    # One emerged run, as the two series its samples carry at or after its confirmed
    # crossing.
    Reading = Data.define(:series) do
      def measured?(observable) = points(observable).any?

      # The highest reading after the crossing, which is a ceiling rather than a level the
      # run settled at: nothing here says the run stayed there.
      def peak(observable) = values_of(observable).max

      def last_of(observable) = values_of(observable).last

      # Rising is the last reading against the middle of the run's own post-crossing
      # readings, not against its first: one step up right after the crossing is a step,
      # not a world still climbing.
      def rising?(observable)
        points(observable).size >= 2 && last_of(observable) > Median.of(values_of(observable))
      end

      def values_of(observable) = points(observable).map(&:last)

      def points(observable) = series.fetch(observable, [])
    end

    # One arm of a sweep: the runs of that grid value that emerged and were measured, over
    # the runs of that grid value that reached an end at all.
    Arm = Data.define(:value, :label, :control, :terminal_count, :readings) do
      def control? = control

      def measured(observable) = readings.select { |reading| reading.measured?(observable) }

      def measured_count(observable) = measured(observable).size

      def rising_count(observable) = measured(observable).count { |reading| reading.rising?(observable) }

      def peaks(observable) = measured(observable).map { |reading| reading.peak(observable) }

      def median_peak(observable) = Median.of(peaks(observable))

      def above_count(observable, threshold)
        return 0 if threshold.nil?

        peaks(observable).count { |peak| peak > threshold }
      end

      def comparable?(observable) = measured_count(observable) >= MIN_ARM_RUNS

      # A whole seed-block run to its end with nothing emerged. Such an arm carries no
      # reading on either observable, so it can never raise the plateau — a world with no
      # replicator has no replicator complexity — and the sweep has tested it as hard as it
      # tested the arms that did emerge.
      def barren? = emerged_count.zero? && terminal_count >= MIN_BARREN_RUNS

      def emerged_count = readings.size
    end

    # One hypothesis: a sweep, its arms and the verdict its own runs support. The same
    # object serves the other observable of the same sweep, read but not decided, through
    # `with(decided_by:)`.
    Bet = Data.define(:slug, :experiment, :arms, :decided_by) do
      def experiment? = experiment.present?

      def control_arm = arms.find(&:control?)

      def treated_arms = arms.reject(&:control?)

      def comparable_arms = treated_arms.select { |arm| arm.comparable?(decided_by) }

      def barren_arms = treated_arms.select(&:barren?)

      def untestable_arms = treated_arms.reject { |arm| arm.comparable?(decided_by) || arm.barren? }

      def control_comparable? = control_arm&.comparable?(decided_by).present?

      def control_barren? = control_arm&.barren?.present?

      def control_median_peak = control_arm&.median_peak(decided_by)

      # An arm raises the peak when most of its runs read strictly above the median of the
      # control arm's runs. A majority, not a mean: the reading is a count.
      def raises?(arm) = arm.above_count(decided_by, control_median_peak) * 2 > arm.measured_count(decided_by)

      def raising_arms = control_comparable? ? comparable_arms.select { |arm| raises?(arm) } : []

      # The refutation DESIGN states is "every treated substrate reads where the default
      # one does", so it needs every treated arm to have been read: an arm nobody seeded
      # leaves the hypothesis untested, however many the others carry. A barren arm has
      # been read — a seed-block of that substrate produced nothing to plateau at, which is
      # as far from raising the plateau as an arm can be — so it counts towards refutation
      # even though it carries no measurement.
      def refutable?
        control_comparable? && (comparable_arms.any? || barren_arms.any?) && untestable_arms.empty?
      end

      def verdict
        return :supported if raising_arms.any?

        refutable? ? :not_supported : :unresolved
      end

      def verdict_label = verdict.to_s.tr("_", " ")

      def badge_class = VERDICT_BADGES.fetch(verdict)

      def measured_count = measured_count_of(decided_by)

      def emerged_count = arms.sum(&:emerged_count)

      def rising_count_of(observable) = arms.sum { |arm| arm.rising_count(observable) }

      def measured_count_of(observable) = arms.sum { |arm| arm.measured_count(observable) }
    end

    def self.build = new

    def bets = @bets ||= BETS.map { |bet| build_bet(bet.fetch(:sweep), bet.fetch(:decided_by)) }

    def bet(slug) = bets.find { |bet| bet.slug == slug }

    def instruction_cost = bet("energy-per-epoch")

    def instruction_cost_complexity = instruction_cost.with(decided_by: :length)

    def environmental_structure = bet("environmental-structure")

    def environmental_structure_lineages = environmental_structure.with(decided_by: :lineages)

    def room_to_grow = bet("max-tape-len")

    def room_to_grow_lineages = room_to_grow.with(decided_by: :lineages)

    def any? = bets.any? { |bet| bet.emerged_count.positive? }

    def emerged_count = bets.sum(&:emerged_count)

    # What the detector flagged over the same three sweeps, against what a replicator
    # confirmed: the page prints both, because most of the difference is the detector
    # firing on a random fill settling (`docs/design_record.md`, 2026-09-15).
    def flagged_count
      @flagged_count ||= Run.transitioned.where(experiment_id: experiments_by_slug.values.map(&:id)).count
    end

    def rising_count(observable) = bets.sum { |bet| bet.rising_count_of(observable) }

    def measured_count(observable) = bets.sum { |bet| bet.measured_count_of(observable) }

    private

    def build_bet(sweep, decided_by)
      slug = Lab.slug_for(sweep)
      axis = Experiments::Axis.sweep(Lab::SWEEPS.fetch(sweep).fetch(:param_grid)).first
      experiment = experiments_by_slug[slug]

      Bet.new(slug: slug, experiment: experiment, decided_by: decided_by,
              arms: arms_of(axis, runs_by_experiment.fetch(experiment&.id, []),
                            terminal_params_by_experiment.fetch(experiment&.id, [])))
    end

    # The control is the first value of the grid — the substrate every earlier sweep ran,
    # as `Lab::SWEEPS` states for each of the three — so the sweep table stays the one
    # place that says which arm is off.
    def arms_of(axis, runs, terminal_params)
      axis.values.map do |value|
        arm_runs = runs.select { |run| axis.matches?(run.params, value) }

        Arm.new(value: value, label: axis.label_of(value), control: value == axis.values.first,
                terminal_count: terminal_params.count { |params| axis.matches?(params, value) },
                readings: arm_runs.map { |run| Reading.new(series: series_by_run.fetch(run.id, {})) })
      end
    end

    def experiments_by_slug
      @experiments_by_slug ||= Experiment.where(slug: BETS.map { |bet| Lab.slug_for(bet.fetch(:sweep)) })
                                         .index_by(&:slug)
    end

    def runs_by_experiment
      @runs_by_experiment ||= Run.emerged.where(experiment_id: experiments_by_slug.values.map(&:id))
                                 .order(:emergence_epoch, :id).to_a.group_by(&:experiment_id)
    end

    # How many runs of each arm reached an end, emerged or not: the readings above hold
    # only emerged runs, and an arm that drew its whole seed-block blank is read off the
    # runs it finished. A run that reported no sample never ran a world anyone can read, so
    # a runner that died on its first epoch does not count as a seed spent on that arm.
    def terminal_params_by_experiment
      @terminal_params_by_experiment ||=
        Run.terminal.where(experiment_id: experiments_by_slug.values.map(&:id), id: Sample.select(:run_id))
           .pluck(:experiment_id, :params)
           .group_by(&:first).transform_values { |rows| rows.map(&:last) }
    end

    def emerged_runs = runs_by_experiment.values.flatten

    # One query for the whole page, both observables at once: the two readings are written
    # into the same sample, and a sample the engine reported a null for — no tested tape
    # replicated — drops out of that observable's series while staying in the other's.
    def series_by_run
      @series_by_run ||=
        Sample.joins(:run).where(run_id: emerged_runs.map(&:id))
              .where("samples.epoch >= runs.emergence_epoch")
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
