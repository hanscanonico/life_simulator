# frozen_string_literal: true

module Experiments
  # Checks that a run's measured transition has a world behind it: for every run of the
  # experiment that settled a `transition_epoch`, the stored snapshot nearest to it, why
  # the run loop took that snapshot and how far off it fell. A transition more than one
  # sample away from any snapshot cannot be rescored (DESIGN.md §1.2), so the report also
  # counts the snapshots by reason — the forced ones are the ones that keep that from
  # happening.
  #
  # It reads stored rows and changes nothing.
  class SnapshotAuditService
    include Callable

    COLUMNS = %w[run_id transition_epoch snapshot_epoch reason epochs_away samples_away].freeze
    # `sample_every` is the runner's business, not a run parameter (Lab::Schema's
    # NON_RUN_PARAMS), so a run that does not carry it was sampled at the engine default.
    SAMPLE_EVERY = Lab::Schema.defaults.fetch("sample_every")

    Row = Data.define(:run_id, :transition_epoch, :snapshot_epoch, :reason, :sample_every) do
      def epochs_away = snapshot_epoch && (snapshot_epoch - transition_epoch).abs

      def samples_away = epochs_away&.fdiv(sample_every)&.ceil

      def covered? = !samples_away.nil? && samples_away <= 1

      def cells = [run_id, transition_epoch, snapshot_epoch, reason, epochs_away, samples_away]
    end

    Report = Data.define(:rows, :reason_counts) do
      def uncovered = rows.reject(&:covered?)

      def to_text
        [table(COLUMNS, rows.map(&:cells)), "\n", summary].join
      end

      private

      def summary
        counted = reason_counts.map { |reason, count| "#{reason} #{count}" }.join(", ")

        "#{rows.size} runs with a transition, #{uncovered.size} of them with no snapshot within one sample\n" \
          "snapshots by reason: #{counted}\n"
      end

      def table(columns, cells)
        lines = [columns, *cells.map { |row| row.map { |cell| cell.nil? ? "—" : cell.to_s } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = Report.new(rows: rows, reason_counts: reason_counts)

    private

    def rows
      @rows ||= transitioned.map { |run| row(run) }
    end

    # A tie goes to the earlier epoch, the tie-break Runs::PruneSnapshotsService picks its
    # kept world by, so the audit names the snapshot that survives thinning rather than
    # whichever row the database handed back first.
    def row(run)
      nearest = snapshots[run.id].to_a.min_by { |epoch, _| [(epoch - run.transition_epoch).abs, epoch] }

      Row.new(run_id: run.id, transition_epoch: run.transition_epoch, snapshot_epoch: nearest&.first,
              reason: nearest&.last, sample_every: run.params.fetch("sample_every", SAMPLE_EVERY))
    end

    def transitioned
      @transitioned ||= @experiment.runs.where.not(transition_epoch: nil).order(:id).to_a
    end

    def snapshots
      @snapshots ||= Snapshot.where(run: transitioned).pluck(:run_id, :epoch, :reason)
                             .group_by(&:first)
                             .transform_values { |rows| rows.map { |(_, epoch, reason)| [epoch, reason] } }
    end

    # Every reason is named, a reason nothing was taken for included: "age 0" is itself a
    # reading of the runner's wall-clock floor.
    def reason_counts
      counted = Snapshot.where(run: @experiment.runs).group(:reason).count

      Snapshot::REASONS.index_with { |reason| counted.fetch(reason, 0) }
    end
  end
end
