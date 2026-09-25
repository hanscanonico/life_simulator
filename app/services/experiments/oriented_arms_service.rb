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
  # A run nothing has read under the instrument is not measured, and counts in neither
  # census column nor either cross-tab: a missing reading is no zero. Its first replicator
  # epoch is only as fine as the readings — stored worlds about every 1000 epochs apart —
  # so the median is coarse.
  #
  # Three queries whatever the sweep holds: the runs, then Runs::OrientedSummariesService.
  class OrientedArmsService
    include Callable
    include GroupsRunsByArm

    COLUMNS = %w[arm n measured flagged emerged replicator_worlds held_to_end replicators_not_emerged
                 emerged_without_replicators median_first_replicator_epoch_coarse].freeze

    Row = Data.define(:flagged, :emerged, :summary) do
      delegate :measured?, :replicator_world?, :held_to_end?, to: :summary
    end

    Arm = Data.define(:label, :rows) do
      def runs = rows.size

      def measured = rows.count(&:measured?)

      def flagged = rows.count(&:flagged)

      def emerged = rows.count(&:emerged)

      def replicator_worlds = rows.count(&:replicator_world?)

      def held_to_end = rows.count(&:held_to_end?)

      def replicators_not_emerged = rows.count { |row| row.replicator_world? && !row.emerged }

      def emerged_without_replicators = rows.count { |row| row.emerged && row.measured? && !row.replicator_world? }

      def median_first_replicator_epoch
        Findings::Median.of(rows.select(&:replicator_world?).map { |row| row.summary.first_replicator_epoch })
      end

      def cells
        [label, runs, measured, flagged, emerged, replicator_worlds, held_to_end, replicators_not_emerged,
         emerged_without_replicators, median_first_replicator_epoch]
      end
    end

    Report = Data.define(:arms) do
      def total = Arm.new(label: "all", rows: arms.flat_map(&:rows))

      def measured? = arms.any? { |arm| arm.measured.positive? }

      def to_text = [table(COLUMNS, [*arms, total].map(&:cells)), "\n", NOTE].join

      def to_csv
        CSV.generate do |csv|
          csv << COLUMNS
          arms.each { |arm| csv << arm.cells }
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
           "stored worlds are read about every 1000 epochs, so a first replicator epoch is no finer than that\n".freeze

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = Report.new(arms: arms_of(runs))

    private

    def arm(label, arm_runs) = Arm.new(label: label, rows: arm_runs.map { |run| row(run) })

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
