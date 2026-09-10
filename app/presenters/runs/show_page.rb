# frozen_string_literal: true

module Runs
  # One run, in full: its metric series, its snapshots and the `(params, seed)` that
  # reproduce it (DESIGN.md §1.1 — a run is fully determined by those two).
  class ShowPage
    METRICS = {
      "compress_ratio" => "Compression ratio",
      "distinct_tapes" => "Distinct tapes",
      "top_share" => "Share of the most common tape",
      "replicator_count" => "Replicator count",
      "op_density" => "Instruction density",
      "entropy_bits" => "Entropy (bits)",
      "copy_rate" => "Copy rate"
    }.freeze

    def self.build(run:) = new(run: run)

    def initialize(run:)
      @run = run
    end

    attr_reader :run

    def charts
      @charts ||= METRICS.map do |metric, title|
        Charts::LineChart.new(points: points_for(metric), title: title, x_label: "Epoch", y_label: title,
                              marker: run.transition_epoch)
      end
    end

    def started? = run.epochs_done.positive?

    # A run reports its first sample only once it has run an epoch, so nothing can be
    # plotted before then.
    def charts_empty? = !started? || charts.all?(&:empty?)

    def transition_label
      return ActiveSupport::NumberHelper.number_to_delimited(run.transition_epoch) if run.transition_epoch

      run.terminal? ? "no emergence" : "no emergence yet"
    end

    def snapshots = @snapshots ||= run.snapshots.where.not(png: nil).order(:epoch).select(:id, :epoch, :updated_at)

    def params = run.params.sort.to_h

    def progress
      return 0.0 if run.epochs.zero?

      (run.epochs_done.fdiv(run.epochs) * 100).round(1)
    end

    private

    def samples = @samples ||= run.samples.order(:epoch).pluck(:epoch, :values)

    def points_for(metric)
      samples.filter_map do |epoch, values|
        value = values[metric]
        [epoch, value] if value.is_a?(Numeric)
      end
    end
  end
end
