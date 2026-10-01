# frozen_string_literal: true

module Runs
  # Stores a batch of one instrument's readings of the run's stored worlds. Re-reading a
  # world rewrites its row rather than adding one: the upsert keys on the
  # `[run_id, instrument, epoch]` unique index. The values are the engine's free-form keys,
  # but each row's shape is checked before any is written, since `upsert_all` skips
  # validations and a malformed batch must store nothing. A batch that reads the same epoch
  # twice keeps the later reading, as a second request would.
  class RecordReadingsService
    include Callable

    def initialize(run:, instrument:, readings:)
      @run = run
      @instrument = instrument
      @readings = readings
    end

    def call
      return @run if @readings.blank?

      SnapshotReading.upsert_all(rows, unique_by: %i[run_id instrument epoch], record_timestamps: true)
      @run
    end

    private

    def rows
      measured_at = Time.current
      @readings.map { |reading| row(reading, measured_at) }.index_by { |row| row["epoch"] }.values
    end

    def row(reading, measured_at)
      record = SnapshotReading.new(run: @run, instrument: @instrument, epoch: reading["epoch"],
                                   source_epoch: reading["source_epoch"], values: reading["values"],
                                   measured_at: measured_at)
      record.validate!
      record.attributes.slice("run_id", "instrument", "epoch", "source_epoch", "values", "measured_at")
    end
  end
end
