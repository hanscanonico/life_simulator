# frozen_string_literal: true

module Runs
  # Stores a batch of `top_k` readings of the run's stored worlds. Re-measuring a world
  # rewrites its rows rather than adding to them: the upsert keys on the
  # `[run_id, epoch, top_k]` unique index.
  class RecordRescoresService
    include Callable

    def initialize(run:, rescores:)
      @run = run
      @rescores = rescores
    end

    def call
      return @run if @rescores.blank?

      Rescore.upsert_all(rows, unique_by: %i[run_id epoch top_k], record_timestamps: true)
      @run
    end

    private

    def rows
      measured_at = Time.current
      @rescores.map do |rescore|
        readings(rescore).merge(run_id: @run.id, epoch: rescore["epoch"], top_k: rescore["top_k"],
                                measured_at: measured_at)
      end
    end

    def readings(rescore) = Rescore::READINGS.index_with { |reading| rescore[reading] }.symbolize_keys
  end
end
