# frozen_string_literal: true

require "csv"

module Experiments
  # One instrument's readings of a sweep's stored worlds as CSV lines: one row per reading,
  # with a column per value the instrument recorded, so the lab can pull a re-read series
  # without SQL. The value columns are the instrument's own keys, in name order — the
  # engine names them, and Rails only lists what it stored.
  #
  # Yields an enumerator and reads the rows in keyset batches over the sort key, as
  # RescoresCsvService does, so a whole sweep's pass is never held in memory.
  class ReadingsCsvService
    include Callable
    include NamesRunArms

    BATCH_SIZE = 500

    COLUMNS = %w[run_id seed arm epoch source_epoch].freeze

    def initialize(experiment:, instrument:)
      @experiment = experiment
      @instrument = instrument
    end

    def call
      Enumerator.new do |lines|
        keys = value_keys
        lines << CSV.generate_line(COLUMNS + keys)
        each_reading { |reading| lines << CSV.generate_line(row(reading, keys)) }
      end
    end

    private

    def readings = SnapshotReading.where(run_id: runs.keys, instrument: @instrument)

    def value_keys
      readings.distinct.pluck(Arel.sql("jsonb_object_keys(\"snapshot_readings\".\"values\")")).sort
    end

    def each_reading(&emit)
      after = nil
      loop do
        batch = batch_after(after)
        batch.each(&emit)
        break if batch.size < BATCH_SIZE

        last = batch.last
        after = [last.run_id, last.epoch]
      end
    end

    def batch_after(key)
      scope = readings.order(:run_id, :epoch).limit(BATCH_SIZE)
      key ? scope.where("(run_id, epoch) > (?, ?)", *key).to_a : scope.to_a
    end

    def row(reading, keys)
      run = runs.fetch(reading.run_id)

      [run.id, run.seed, arm_label(run), reading.epoch, reading.source_epoch] + reading.values.values_at(*keys)
    end

    def runs
      @runs ||= experiment.runs.order(:id).select(:id, :seed, :params).index_by(&:id)
    end

    attr_reader :experiment
  end
end
