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
      "copy_rate" => "Copy rate",
      "distinct_lineages" => "Distinct lineages",
      "top_lineage_share" => "Share of the largest lineage",
      "lineage_variation" => "Variation within a lineage",
      "copy_cost" => "Copy cost (steps)",
      "dominant_compressed_len" => "Compressed length of the dominant tape (bytes)",
      "dominant_instruction_count" => "Instructions in the dominant tape",
      "dominant_raw_len" => "Length of the dominant tape (bytes)",
      "conserved_core_bytes" => "Conserved core of the largest lineage (bytes)",
      "conserved_core_ops" => "Instructions in that conserved core",
      "steal_rate" => "Steal rate",
      "replicator_pass_rate" => "Census pass rate",
      "replicator_count_mean" => "Mean census count"
    }.freeze

    COMPRESSIBILITY_TITLE = "Compressed over raw length of the dominant tape"
    TURNOVER_TITLE = "Dominant tape turnover (1 = a different tape than the sample before)"
    # The y title is drawn rotated inside a gutter the height of the plot (240 user units,
    # `Charts::Plot`), so a name much past twenty characters is clipped at both ends. These
    # two say in the caption what the axis cannot.
    COMPRESSIBILITY_AXIS = "Compressed / raw"
    TURNOVER_AXIS = "Turnover (0 or 1)"

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
      @charts ||= METRICS.map { |metric, title| chart_of(MetricSeriesService.call(run: run, metric: metric), title) } +
                  [chart_of(compressibility_points, COMPRESSIBILITY_TITLE, axis: COMPRESSIBILITY_AXIS),
                   chart_of(turnover_points, TURNOVER_TITLE, axis: TURNOVER_AXIS)]
    end

    # zlib wraps an incompressible tape in 11 bytes, so a tape of junk compresses to a
    # little more than its own length and the compressed reading alone cannot be told from
    # the tape cap (DESIGN §1.2). Read against the raw length it can: near 1 is junk.
    def compressibility_points
      @compressibility_points ||= dominant_readings.filter_map do |epoch, values|
        compressed = values["dominant_compressed_len"]
        raw = values["dominant_raw_len"]
        [epoch, compressed / raw.to_f] if compressed.is_a?(Numeric) && raw.is_a?(Numeric) && raw.positive?
      end
    end

    # Whether the dominant tape kept its identity from one sample to the next, read off the
    # engine's hash of its bytes. The first sample of a run has nothing to differ from.
    def turnover_points
      @turnover_points ||= tape_hashes.each_cons(2)
                                      .map { |(_, before), (epoch, after)| [epoch, after == before ? 0 : 1] }
    end

    def findings = @findings ||= Findings::Registry.for_experiment(run.experiment.slug)

    # Only a run the detector flagged has one, and only once its finish — or
    # `rake lab:backfill_persistence` — has derived it from the samples.
    def persistence = run.persistence_summary

    def census_peak_label = persistence.census_label

    def charts_empty? = charts.all?(&:empty?)

    def transition_label
      return delimited(run.transition_epoch) if run.transition_epoch

      run.terminal? ? "no emergence" : "no emergence yet"
    end

    # A run is named by its sweep, its arm and its seed (DESIGN.md §1.1), so the line a
    # search result or a shared link shows names it the same way rather than by its id alone.
    def meta_description
      arm = arm_label ? " (#{arm_label})" : ""

      "Run ##{run.id} of the #{run.experiment.name} sweep#{arm}, seed #{run.seed}: " \
        "#{run.status}, #{delimited(run.epochs_done)} of #{delimited(run.epochs)} epochs, #{emergence_label}."
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

    def tape_hashes
      dominant_readings.filter_map do |epoch, values|
        hash = values["dominant_tape_hash"]
        [epoch, hash] if hash.is_a?(String)
      end
    end

    def chart_of(points, title, axis: title)
      Charts::LineChart.new(points: points, title: title, x_label: "Epoch", y_label: axis,
                            marker: run.transition_epoch)
    end

    # The same rows every series is read from: identical SQL inside one request is served
    # by the query cache.
    def dominant_readings = @dominant_readings ||= run.samples.order(:epoch).pluck(:epoch, :values)

    def emergence_label
      return transition_label unless run.transition_epoch

      "self-replicators from epoch #{delimited(run.transition_epoch)}"
    end

    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)

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
