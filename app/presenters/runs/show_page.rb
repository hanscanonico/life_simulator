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
      "alphabet_size" => "Alphabet size",
      "copy_rate" => "Copy rate"
    }.freeze

    SAMPLE_CLOCK = "COUNT(*), MIN(epoch), MAX(epoch), MIN(created_at), MAX(created_at)"
    # The rows of one batch (50 samples, `http_sink::BATCH_SIZE`) share a wall-clock instant
    # to within milliseconds, so a narrow span is the width of one write and not a
    # measurement: dividing by it reports megaepochs a second. A minute of observed time is
    # the floor under which this page says nothing rather than something impossible.
    MIN_MEASURED_SECONDS = 60

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

    def findings = @findings ||= Findings::Registry.for_experiment(run.experiment.slug)

    # Only a run the detector flagged has one, and only once its finish — or
    # `rake lab:backfill_persistence` — has derived it from the samples.
    def persistence = run.persistence_summary

    # A run none of whose samples carried a `replicator_count` has no census reading at
    # all, which is a gap in the record and not a peak that happened to be zero.
    def census_peak_label
      return "— (not sampled)" unless persistence.sampled?
      return "0 (no replicator counted)" unless persistence.counted?

      ActiveSupport::NumberHelper.number_to_delimited(persistence.census_peak)
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
      return nil if sample_count < 2 || epoch_span <= 0 || seconds_span < MIN_MEASURED_SECONDS

      (epoch_span / seconds_span).round(2)
    end

    # What the run cost, as opposed to how fast it is going now: every epoch it has done
    # over every second of compute it has been given, summed beat by beat across resumes
    # (`runs.compute_seconds`). A run claimed before the runner sent its intervals has
    # none, and says nothing rather than something wrong.
    def epochs_per_compute_second
      return nil unless run.compute_seconds.positive?

      (run.epochs_done / run.compute_seconds).round(2)
    end

    def compute_hours = (run.compute_seconds / 3600).round(2)

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
