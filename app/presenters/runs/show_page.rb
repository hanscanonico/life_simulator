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
        Charts::LineChart.new(points: MetricSeriesService.call(run: run, metric: metric), title: title,
                              x_label: "Epoch", y_label: title, marker: run.transition_epoch)
      end
    end

    # The write-ups that rest on this run's sweep, read from the registry rather than
    # queried: a finding is content in the repo, not a row.
    def findings
      @findings ||= Findings::Registry.all.select { |finding| finding.experiment_slug == run.experiment.slug }
    end

    def charts_empty? = charts.all?(&:empty?)

    def transition_label
      return ActiveSupport::NumberHelper.number_to_delimited(run.transition_epoch) if run.transition_epoch

      run.terminal? ? "no emergence" : "no emergence yet"
    end

    # The arm this run sits in, named the way the sweep's own tables name it:
    # Experiments::Axis is the only place that knows radius 0 reads "well-mixed".
    def arm_label = @arm_label ||= arm_labels.join(", ").presence

    def snapshots = @snapshots ||= run.snapshots.where.not(png: nil).order(:epoch).select(:id, :epoch, :updated_at)

    def params = run.params.sort.to_h

    def progress
      return 0.0 if run.epochs.zero?

      (run.epochs_done.fdiv(run.epochs) * 100).round(1)
    end

    private

    def arm_labels
      Experiments::Axis.sweep(run.experiment.param_grid).filter_map { |axis| axis.label_of_run(run.params) }
    end
  end
end
