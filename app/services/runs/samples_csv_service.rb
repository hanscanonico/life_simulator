# frozen_string_literal: true

require "csv"

module Runs
  # One run's whole metric series as CSV lines, in epoch order. Yields an enumerator and
  # reads the rows in keyset batches, so exporting a run with thousands of samples holds
  # neither the rows nor the output in memory.
  class SamplesCsvService
    include Callable

    BATCH_SIZE = 500

    def initialize(run:)
      @run = run
    end

    def call
      Enumerator.new do |lines|
        lines << CSV.generate_line(["epoch"] + Sample::OBSERVABLES)
        each_sample { |sample| lines << CSV.generate_line(row(sample)) }
      end
    end

    private

    def each_sample(&emit)
      after = nil
      loop do
        batch = batch_after(after)
        batch.each(&emit)
        break if batch.size < BATCH_SIZE

        after = batch.last.epoch
      end
    end

    def batch_after(epoch)
      scope = @run.samples.order(:epoch).select(:epoch, :values).limit(BATCH_SIZE)
      epoch ? scope.where(epoch: (epoch + 1)..).to_a : scope.to_a
    end

    def row(sample) = [sample.epoch] + Sample::OBSERVABLES.map { |observable| sample.values[observable] }
  end
end
