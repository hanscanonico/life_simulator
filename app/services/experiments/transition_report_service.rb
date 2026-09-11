# frozen_string_literal: true

require "csv"

module Experiments
  # Reconciles the transition detector with the replicator census over an experiment's
  # stored samples. `transition_epoch` fires on `compress_ratio` alone, so a run can be
  # flagged with no replicator ever counted, and a run whose replicator count rose can go
  # unflagged; a claim about emergence has to hold on both observables (DESIGN.md §1.2),
  # and this is where the two are read side by side, run by run and arm by arm.
  #
  # It reads stored samples and changes nothing — not the detector, not a metric, not a run.
  class TransitionReportService
    include Callable

    THRESHOLD = Lab::Schema.transition.fetch("threshold")

    RUN_COLUMNS = %w[run_id seed].freeze
    SAMPLE_COLUMNS = %w[
      transition_epoch collapse_epoch min_entropy_bits min_entropy_epoch peak_replicator_count
      peak_replicator_epoch first_replicator_epoch peak_copy_rate peak_copy_rate_epoch
      final_compress_ratio final_distinct_tapes final_top_share
    ].freeze

    Row = Data.define(:run_id, :seed, :params, :transition_epoch, :collapse_epoch,
                      :min_entropy_bits, :min_entropy_epoch, :peak_replicator_count,
                      :peak_replicator_epoch, :first_replicator_epoch, :peak_copy_rate,
                      :peak_copy_rate_epoch, :final_compress_ratio, :final_distinct_tapes,
                      :final_top_share) do
      def cells
        [run_id, seed, *params.values, *SAMPLE_COLUMNS.map { |column| public_send(column) }]
      end
    end

    Report = Data.define(:rows, :arms, :param_keys) do
      def headers = [*RUN_COLUMNS, *param_keys, *SAMPLE_COLUMNS]

      def to_text
        [table(headers, rows.map(&:cells)), table(TransitionArmsService::COLUMNS, arms.map(&:cells))].join("\n")
      end

      def to_csv
        CSV.generate do |csv|
          csv << headers
          rows.each { |row| csv << row.cells }
          csv << []
          csv << TransitionArmsService::COLUMNS
          arms.each { |arm| csv << arm.cells }
        end
      end

      private

      def table(columns, cells)
        lines = [columns, *cells.map { |cells_row| cells_row.map { |cell| format_cell(cell) } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end

      def format_cell(cell)
        return "—" if cell.nil?
        return Charts.format_value(cell) if cell.is_a?(Float)

        cell.to_s
      end
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = Report.new(rows: rows, arms: arms, param_keys: param_keys)

    private

    def rows
      @rows ||= sampled_runs.map { |run, samples| row(run, samples) }
    end

    # The arm block is the arms service's, counted off indexed columns rather than off
    # these rows, so the block the page publishes and the one under the rows cannot drift.
    def arms = TransitionArmsService.call(experiment: @experiment)

    # A run nothing has been sampled from yet is no row: the report is a reading of stored
    # samples, not of the queue.
    def sampled_runs
      runs = @experiment.runs.order(:id).to_a
      by_run = Sample.where(run: runs).order(:epoch).pluck(:run_id, :epoch, :values)
                     .group_by(&:first)

      runs.filter_map do |run|
        samples = by_run[run.id]
        [run, samples.map { |(_, epoch, values)| [epoch, values] }] if samples
      end
    end

    def row(run, samples)
      Row.new(**identity_of(run), **detector_of(run, samples), **census_of(samples), **endpoint_of(samples))
    end

    def identity_of(run)
      { run_id: run.id, seed: run.seed, params: param_keys.index_with { |key| run.params[key] } }
    end

    # `collapse_epoch` is the bare first crossing of the threshold, where
    # `transition_epoch` also demands the hold: the gap between them is a candidate that
    # never settled.
    def detector_of(run, samples)
      entropy = extreme(samples, "entropy_bits", :min_by)

      { transition_epoch: run.transition_epoch,
        collapse_epoch: samples.find { |(_, values)| below_threshold?(values) }&.first,
        min_entropy_bits: value_of(entropy, "entropy_bits"), min_entropy_epoch: entropy&.first }
    end

    def census_of(samples)
      replicators = extreme(samples, "replicator_count", :max_by)
      copies = extreme(samples, "copy_rate", :max_by)

      { peak_replicator_count: value_of(replicators, "replicator_count"),
        peak_replicator_epoch: peak_epoch_of(replicators, "replicator_count"),
        first_replicator_epoch: samples.find { |(_, values)| values["replicator_count"].to_f.positive? }&.first,
        peak_copy_rate: value_of(copies, "copy_rate"), peak_copy_rate_epoch: peak_epoch_of(copies, "copy_rate") }
    end

    def endpoint_of(samples)
      values = samples.last.last

      { final_compress_ratio: values["compress_ratio"], final_distinct_tapes: values["distinct_tapes"],
        final_top_share: values["top_share"] }
    end

    def extreme(samples, observable, direction)
      samples.select { |(_, values)| values[observable].present? }
             .public_send(direction) { |(_, values)| values[observable] }
    end

    def value_of(sample, observable) = sample && sample.last[observable]

    # A peak of zero happened nowhere in particular, so its epoch stays blank rather than
    # pointing at whichever sample came first.
    def peak_epoch_of(sample, observable)
      sample&.first if value_of(sample, observable).to_f.positive?
    end

    def below_threshold?(values)
      ratio = values["compress_ratio"]

      ratio.present? && ratio < THRESHOLD
    end

    def axes = @axes ||= Axis.sweep(@experiment.param_grid)

    def param_keys = @param_keys ||= axes.flat_map(&:param_keys).uniq
  end
end
