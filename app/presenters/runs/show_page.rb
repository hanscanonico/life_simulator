# frozen_string_literal: true

module Runs
  # One run, in full: its metric series, its snapshots and the `(params, seed)` that
  # reproduce it (DESIGN.md §1.1 — a run is fully determined by those two).
  class ShowPage
    METRICS = MetricTitles::ALL

    # The readings of a run that carries a metabolism tape (DESIGN §1.2): null at every
    # sample of any other run.
    METABOLISM = %w[meta_inherit_rate meta_diversity logic_capability_replicating].freeze

    # The readings of the topless ladder (tasks logic3 or logic4): null at every sample of
    # any other run, the two-input logic ladder's included.
    DEPTH = %w[logic_depth_max logic_depth_classes].freeze

    # The readings of a run whose predation pass runs: null at every sample of any other run.
    PREDATION = %w[predation_rate predation_relation_rate repertoire_mean silent_share].freeze

    # The reading of a metabolism channel that grows, the reading of genes and the readings
    # of fidelity levels: each null at every sample of a run without it.
    GROWTH = %w[meta_len_mean].freeze
    GENES = %w[genes_essential_held].freeze
    FIDELITY = %w[fidelity_p10 fidelity_p50 fidelity_p90].freeze

    # The readings of one task ladder are null at every sample of a run not assayed on it
    # (DESIGN §1.2), so a ladder's charts are drawn only for a run that has a reading of it,
    # rather than as a block of empty charts on every other run. The metabolism, depth,
    # predation, growth, genes and fidelity readings are drawn by the same rule.
    LADDERS = [
      METRICS.keys.grep(/\A(dominant_)?task_/),
      METRICS.keys.grep(/\A(dominant_)?logic_/) - METABOLISM - DEPTH
    ].freeze
    GATED = (LADDERS + [METABOLISM, DEPTH, PREDATION, GROWTH, GENES, FIDELITY]).freeze

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
    DESCENDANTS_SHOWN = 20

    def self.build(run:) = new(run: run)

    def initialize(run:)
      @run = run
    end

    attr_reader :run

    def charts
      @charts ||= drawn_metrics.map { |metric| chart_of(series_of(metric), METRICS.fetch(metric)) } +
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

    # Which way round the dominant tape's copy lay at the last sample that read a
    # `copy_latency`: a word, so it has no chart of its own and is read beside that one.
    def copy_latency_orientation
      @copy_latency_orientation ||= dominant_readings.reverse_each.lazy
                                                     .map { |_, values| values["copy_latency_orientation"] }
                                                     .find { |orientation| orientation.is_a?(String) }
    end

    # The tasks the dominant tape was credited with at the last sample that assayed it, by
    # name: the engine records them as a bitmask in the order of its task ladder. `nil`
    # where no sample read one, so a run with tasks off says nothing rather than "none".
    def dominant_tasks
      return @dominant_tasks if defined?(@dominant_tasks)

      @dominant_tasks = latest_tasks("dominant_tasks", Lab::Schema.task_names)
    end

    def dominant_tasks_label = tasks_label(dominant_tasks)

    # The same, for the logic ladder's `dominant_logic_tasks`: `nil` unless a sample of a
    # run with tasks = logic read one.
    def dominant_logic_tasks
      return @dominant_logic_tasks if defined?(@dominant_logic_tasks)

      @dominant_logic_tasks = latest_tasks("dominant_logic_tasks", Lab::Schema.logic_task_names)
    end

    def dominant_logic_tasks_label = tasks_label(dominant_logic_tasks)

    def findings = @findings ||= Findings::Registry.for_experiment(run.experiment.slug)

    # Only a run the detector flagged has one, and only once its finish — or
    # `rake lab:backfill_persistence` — has derived it from the samples.
    def persistence = run.persistence_summary

    def census_peak_label = persistence.census_label

    def parent = run.parent_run

    def descendants
      @descendants ||= run.descendants.order(:id).limit(DESCENDANTS_SHOWN).select(:id, :seed, :status).to_a
    end

    def descendant_count = @descendant_count ||= run.descendants.count

    def more_descendants? = descendant_count > descendants.size

    def charts_empty? = charts.all?(&:empty?)

    def transition_label
      return delimited(run.transition_epoch) if run.transition_epoch
      return "none of its own (a descendant)" if run.descendant?

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

      (run.own_epochs_done / run.compute_seconds).round(2)
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
      return 0.0 unless run.own_epochs.positive?

      (run.own_epochs_done.fdiv(run.own_epochs) * 100).round(1)
    end

    private

    def tape_hashes
      dominant_readings.filter_map do |epoch, values|
        hash = values["dominant_tape_hash"]
        [epoch, hash] if hash.is_a?(String)
      end
    end

    def latest_tasks(key, ladder)
      bits = dominant_readings.reverse_each.lazy.map { |_, values| values[key] }.find { |mask| mask.is_a?(Integer) }
      bits && ladder.select.with_index { |_, index| bits[index] == 1 }
    end

    def tasks_label(tasks)
      return if tasks.nil?

      tasks.empty? ? "no task" : tasks.map(&:upcase).to_sentence
    end

    def drawn_metrics
      METRICS.keys - GATED.reject { |group| group.any? { |metric| series_of(metric).any? } }.flatten
    end

    def series_of(metric)
      (@series ||= {})[metric] ||= MetricSeriesService.call(run: run, metric: metric, samples: dominant_readings)
    end

    def chart_of(points, title, axis: title)
      Charts::LineChart.new(points: points, title: title, x_label: "Epoch", y_label: axis,
                            marker: run.transition_epoch)
    end

    # The same rows every series is read from, plucked once: the query cache would spare
    # the database a repeat, but not the parse of every sample's JSON.
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
