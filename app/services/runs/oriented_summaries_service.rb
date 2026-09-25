# frozen_string_literal: true

module Runs
  # The orientation-aware summary (Runs::OrientedSummary) of every run given, keyed by run
  # id, in two queries whatever their number. The runs must be loaded with `epochs`.
  #
  # Only the static readings of stored worlds count: `epoch == source_epoch`, at or before
  # the run's last epoch. The corpus pass also steps each world on to the next sample epoch
  # for its in-situ keys, and steps the last one past the run's end; those readings are
  # left out, so no run gains a reading its budget never reached. Live samples are left out
  # too: a run sampled every 10 epochs would get a hundred chances at a one-sample peak for
  # every one a run read off its stored worlds gets. A run the pass has not read every
  # stored world of is unmeasured; the pass is re-run, and resumes, as runs finish.
  class OrientedSummariesService
    include Callable

    INSTRUMENT = Lab::DescendantReading::INSTRUMENT
    # Lab::DescendantReading::SHARE_KEY, read as jsonb so a stored number stays a number.
    SHARE = "snapshot_readings.values -> 'replicator_share'"
    UNREAD = <<~SQL.squish
      NOT EXISTS (SELECT 1 FROM snapshot_readings
                  WHERE snapshot_readings.run_id = snapshots.run_id
                    AND snapshot_readings.instrument = :instrument
                    AND snapshot_readings.epoch = snapshots.epoch
                    AND snapshot_readings.source_epoch = snapshots.epoch)
    SQL

    def initialize(runs:)
      @runs = runs
    end

    def call
      readings = stored_readings
      unread = unread_worlds

      @runs.to_h do |run|
        [run.id, OrientedSummary.new(epochs: run.epochs, readings: readings.fetch(run.id, []),
                                     unread_worlds: unread.fetch(run.id, 0))]
      end
    end

    private

    def unread_worlds
      Snapshot.where(run_id: @runs.map(&:id)).where(UNREAD, instrument: INSTRUMENT).group(:run_id).count
    end

    def stored_readings
      SnapshotReading.joins(:run)
                     .where(run_id: @runs.map(&:id), instrument: INSTRUMENT)
                     .where("snapshot_readings.epoch = snapshot_readings.source_epoch")
                     .where("snapshot_readings.epoch <= runs.epochs")
                     .pluck(:run_id, :epoch, Arel.sql(SHARE))
                     .group_by(&:first)
                     .transform_values { |rows| rows.map { |(_, epoch, share)| OrientedSummary::Reading.new(epoch:, share:) } }
    end
  end
end
