# frozen_string_literal: true

module Runs
  # Ingests a batch of metric samples. Re-posting a batch is a no-op beyond rewriting the
  # same rows: the upsert keys on the `[run_id, epoch]` unique index. A runner retrying an
  # older batch must not rewind the run's summary either, so the summary only moves forward.
  # The run is touched by every batch, even one that leaves its summary alone: the sweep
  # page caches readings of a run's samples under its `updated_at`.
  class RecordSamplesService
    include Callable

    def initialize(run:, samples:, transition_epoch: nil, transition_epoch_relative: nil)
      @run = run
      @samples = samples
      @transition_epoch = transition_epoch
      @transition_epoch_relative = transition_epoch_relative
    end

    def call
      return @run if @samples.blank?

      newest_recorded = Sample.where(run: @run).maximum(:epoch).to_i
      Sample.upsert_all(rows, unique_by: %i[run_id epoch], record_timestamps: true)
      @run.update!(run_attributes(newest_recorded).merge(updated_at: Time.current))
      @run
    end

    private

    def rows
      @samples.map { |sample| { run_id: @run.id, epoch: sample["epoch"], values: metrics(sample) } }
    end

    def metrics(sample) = sample.except("epoch")

    def run_attributes(newest_recorded)
      newest = @samples.max_by { |sample| sample["epoch"].to_i }
      attributes = {}
      attributes[:summary] = metrics(newest) if newest["epoch"].to_i >= newest_recorded
      attributes[:transition_epoch] = @transition_epoch if @run.earlier_transition_epoch?(@transition_epoch)
      if @run.earlier_transition_epoch_relative?(@transition_epoch_relative)
        attributes[:transition_epoch_relative] = @transition_epoch_relative
      end
      attributes
    end
  end
end
