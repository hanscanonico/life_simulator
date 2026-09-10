# frozen_string_literal: true

module Runs
  # Ingests a batch of metric samples. Re-posting a batch is a no-op beyond rewriting the
  # same rows: the upsert keys on the `[run_id, epoch]` unique index.
  class RecordSamplesService
    include Callable

    def initialize(run:, samples:, transition_epoch: nil)
      @run = run
      @samples = samples
      @transition_epoch = transition_epoch
    end

    def call
      return @run if @samples.blank?

      Sample.upsert_all(rows, unique_by: %i[run_id epoch], record_timestamps: true)
      @run.update!(run_attributes)
      @run
    end

    private

    def rows
      @samples.map { |sample| { run_id: @run.id, epoch: sample["epoch"], values: metrics(sample) } }
    end

    def metrics(sample) = sample.except("epoch")

    def run_attributes
      attributes = { summary: metrics(@samples.last) }
      attributes[:transition_epoch] = @transition_epoch unless @transition_epoch.nil?
      attributes
    end
  end
end
