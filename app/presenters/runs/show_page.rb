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

    SAMPLE_CLOCK = "COUNT(*), MIN(epoch), MAX(epoch), MIN(created_at), MAX(created_at)"

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

    # How fast this run is actually burning epochs, measured between its first and last
    # recorded sample. The finish `wall_seconds` covers one segment only — a resumed run
    # has several — and the samples are the one record of progress a release cannot rewrite.
    def epochs_per_second
      return nil if sample_count < 2 || epoch_span.zero? || seconds_span <= 0

      (epoch_span / seconds_span).round(2)
    end

    def eta
      return nil if run.terminal?

      rate = epochs_per_second
      return nil if rate.nil?

      (remaining_epochs / rate).round.seconds
    end

    def snapshots
      @snapshots ||= run.snapshots.where.not(png: nil).order(:epoch).select(:id, :epoch, :reason, :updated_at)
    end

    def params = run.params.sort.to_h

    def progress
      return 0.0 if run.epochs.zero?

      (run.epochs_done.fdiv(run.epochs) * 100).round(1)
    end

    private

    def sample_clock = @sample_clock ||= run.samples.pick(Arel.sql(SAMPLE_CLOCK))

    def sample_count = sample_clock[0]

    def epoch_span = sample_clock[2] - sample_clock[1]

    def seconds_span = sample_clock[4] - sample_clock[3]

    def remaining_epochs = [run.epochs - run.epochs_done, 0].max

    def arm_labels
      Experiments::Axis.sweep(run.experiment.param_grid).filter_map { |axis| axis.named_label_of_run(run.params) }
    end
  end
end
