# frozen_string_literal: true

require "csv"

module Experiments
  # The detector, the emergence rule and the orientation-aware census (#245, #247) side by
  # side, arm by arm, over a sweep's finished founding runs: how many the detector flagged,
  # how many the census or the copy rate confirmed as emerged, and how many worlds held
  # self-replicators by the census that sees reverse copiers. The two cross-tabs are the
  # runs the rules disagree on. It is the evidence a relock of the census or the emergence
  # rule would be argued from; it relocks nothing.
  #
  # The census columns read the corpus pass's readings of stored worlds only
  # (Runs::OrientedSummariesService), so every run is read at one cadence. A run the pass
  # has not reached is not measured, and counts in neither census column nor either
  # cross-tab: a missing reading is no zero. The pass is re-run, and resumes, as runs
  # finish. A first replicator epoch is only as fine as the readings — stored worlds about
  # every 1000 epochs apart — so the median is coarse.
  #
  # Two queries whatever the sweep holds, of about 22 readings a run: the runs, then
  # Runs::OrientedSummariesService.
  class OrientedArmsService
    include Callable
    include GroupsRunsByArm

    COLUMNS = %w[arm n measured flagged emerged replicator_worlds held_to_end replicators_not_emerged
                 emerged_without_replicators median_first_replicator_epoch_coarse].freeze

    Row = Data.define(:flagged, :emerged, :summary) do
      delegate :measured?, :replicator_world?, :held_to_end?, :first_replicator_epoch, to: :summary

      def flagged? = flagged

      def emerged? = emerged

      def replicators_not_emerged? = replicator_world? && !emerged

      # An unmeasured run is no run without replicators: nothing has read it.
      def emerged_without_replicators? = emerged && measured? && !replicator_world?
    end

    # Each count but `runs`, and the Row predicate it counts.
    COUNTED = { measured: :measured?, flagged: :flagged?, emerged: :emerged?,
                replicator_worlds: :replicator_world?, held_to_end: :held_to_end?,
                replicators_not_emerged: :replicators_not_emerged?,
                emerged_without_replicators: :emerged_without_replicators? }.freeze
    COUNTS = [:runs, *COUNTED.keys].freeze

    # An arm reduced to its counts as it is built, so no reading outlives the arm that read
    # it: only the first replicator epochs of its replicator worlds are kept, for the median
    # and for a total over arms.
    Arm = Data.define(:label, :runs, :measured, :flagged, :emerged, :replicator_worlds, :held_to_end,
                      :replicators_not_emerged, :emerged_without_replicators, :first_replicator_epochs) do
      def self.of(label, rows)
        counts = COUNTED.transform_values { |predicate| rows.count(&predicate) }

        new(label: label, runs: rows.size, **counts,
            first_replicator_epochs: rows.select(&:replicator_world?).map(&:first_replicator_epoch))
      end

      def self.sum(label, arms)
        new(label: label, **COUNTS.index_with { |count| arms.sum(&count) },
            first_replicator_epochs: arms.flat_map(&:first_replicator_epochs))
      end

      def median_first_replicator_epoch = Findings::Median.of(first_replicator_epochs)

      def cells = [label, *COUNTS.map { |count| public_send(count) }, median_first_replicator_epoch]
    end

    Report = Data.define(:arms) do
      def total = Arm.sum("all", arms)

      def measured? = arms.any? { |arm| arm.measured.positive? }

      def to_text = [table(COLUMNS, [*arms, total].map(&:cells)), "\n", NOTE].join

      def to_csv
        CSV.generate do |csv|
          csv << COLUMNS
          [*arms, total].each { |arm| csv << arm.cells }
        end
      end

      private

      def table(columns, cells)
        lines = [columns, *cells.map { |row| row.map { |cell| cell.nil? ? "—" : cell.to_s } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end
    end

    NOTE = "finished founding runs; the census columns read #{Lab::DescendantReading::INSTRUMENT} " \
           "(share >= #{Lab::DescendantReading::QUALIFYING_SHARE}) and count measured runs only;\n" \
           "only stored worlds are read, about every 1000 epochs, so a first replicator epoch is no finer " \
           "than that;\na run the corpus pass has not reached is unmeasured\n".freeze

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = Report.new(arms: arms_of(runs))

    private

    def arm(label, arm_runs) = Arm.of(label, arm_runs.map { |run| row(run) })

    def row(run)
      Row.new(flagged: run.transition_epoch.present?, emerged: run.emerged?, summary: summaries.fetch(run.id))
    end

    def summaries = @summaries ||= Runs::OrientedSummariesService.call(runs: runs)

    def runs
      @runs ||= experiment.runs.founding.where(status: "finished").order(:id)
                          .select(:id, :params, :epochs, :transition_epoch, :emergence_epoch).to_a
    end

    attr_reader :experiment
  end
end
