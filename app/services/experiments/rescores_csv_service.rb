# frozen_string_literal: true

require "csv"

module Experiments
  # Every rescore of a sweep as CSV lines: one reading per stored world per `top_k`, so a
  # proposal to move the `top_k` of 16 locked for a run's own metrics (DESIGN.md §1.2) can
  # be argued from the raw readings and not only from the page's summary.
  #
  # Yields an enumerator and reads the rows in keyset batches over the sort key, so
  # exporting a corpus pass over a whole sweep holds neither the rows nor the output in
  # memory. The runs are read once, for their seeds and their arm labels.
  class RescoresCsvService
    include Callable

    BATCH_SIZE = 500

    COLUMNS = %w[run_id seed arm epoch top_k].freeze

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Enumerator.new do |lines|
        lines << CSV.generate_line(COLUMNS + Rescore::READINGS)
        each_rescore { |rescore| lines << CSV.generate_line(row(rescore)) }
      end
    end

    private

    def each_rescore(&emit)
      after = nil
      loop do
        batch = batch_after(after)
        batch.each(&emit)
        break if batch.size < BATCH_SIZE

        last = batch.last
        after = [last.run_id, last.epoch, last.top_k]
      end
    end

    def batch_after(key)
      scope = Rescore.where(run_id: runs.keys).order(:run_id, :epoch, :top_k).limit(BATCH_SIZE)
      key ? scope.where("(run_id, epoch, top_k) > (?, ?, ?)", *key).to_a : scope.to_a
    end

    def row(rescore)
      run = runs.fetch(rescore.run_id)

      [run.id, run.seed, arm_label(run), rescore.epoch, rescore.top_k] +
        Rescore::READINGS.map { |reading| rescore.public_send(reading) }
    end

    def runs
      @runs ||= @experiment.runs.order(:id).select(:id, :seed, :params).index_by(&:id)
    end

    def arm_label(run)
      labels = axes.filter_map { |axis| axis.named_label_of_run(run.params) }

      labels.empty? ? @experiment.slug : labels.join(" ")
    end

    def axes = @axes ||= Axis.sweep(@experiment.param_grid)
  end
end
