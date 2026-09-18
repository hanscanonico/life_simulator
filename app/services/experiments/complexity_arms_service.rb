# frozen_string_literal: true

module Experiments
  # The pre-registered complexity reading of DESIGN §1.3 sweep 9, arm by arm: does the
  # dominant tape keep getting more complicated where energy is a contested stock, or does
  # it plateau as it did on every substrate before it?
  #
  # Taken on emerged runs only — a crossing the census or the copy rate confirmed, not
  # every crossing the detector flagged. Per run it compares the median of the last decile
  # of the post-crossing samples against the median of the first decile: a rise of at least
  # RISE_MARGIN in `dominant_instruction_count` with the conserved core not falling over the
  # same span is a run that keeps rising, and a last decile within PLATEAU_BAND of the first
  # is a run that plateaued. `dominant_compressed_len` is carried beside them and decides
  # nothing: it saturates at the tape cap plus zlib's envelope (`docs/design_record.md`,
  # 2026-09-16). An arm reads with MIN_ARM_RUNS measured runs, or with a blank block of
  # MIN_BARREN_RUNS; a steal arm whose `steal_rate` never left zero reads as theft that
  # never evolved rather than as theft that does not help, and one no `steal_rate` was ever
  # sampled on reads as theft unmeasured rather than as theft that never evolved.
  #
  # It publishes the arms it has something to say about: an arm with no measured run, no
  # blank block and no steal op carries no row at all.
  #
  # Every number here is an engine reading composed by arm; nothing re-implements a metric.
  # It reads stored samples and changes nothing.
  class ComplexityArmsService
    include Callable
    include GroupsRunsByArm

    INSTRUCTIONS = "dominant_instruction_count"
    CORE = "conserved_core_bytes"
    COMPRESSED = "dominant_compressed_len"
    STEAL_RATE = "steal_rate"
    STEAL_AMOUNT = "steal_amount"

    RISE_MARGIN = 0.2
    PLATEAU_BAND = 0.1
    MIN_ARM_RUNS = 2
    MIN_BARREN_RUNS = 10

    COLUMNS = %w[
      arm emerged measured instructions_first instructions_last core_first core_last
      compressed_first compressed_last rising plateau peak_steal_rate theft reading
    ].freeze

    READING_BADGES = { keeps_rising: "badge-success", plateau: "badge-warning", mixed: "badge-info",
                       neither: "badge-error", unread: "badge-info", barren: "badge-error" }.freeze

    # The two decile medians of one observable over one run's post-crossing samples.
    Span = Data.define(:first, :last) do
      # A span starting at zero has no ratio at all: nothing rose or plateaued by a
      # percentage of nothing, so it is unmeasured rather than flat or infinite.
      def measured? = !first.zero?

      def growth = last / first.to_f

      def rose_by?(margin) = measured? && growth >= 1 + margin

      def fell? = measured? && growth < 1.0

      def flat_within?(band) = measured? && growth.between?(1 - band, 1 + band)
    end

    # The pre-registered rule reads the instruction count and the conserved core over the
    # same span, so a run carrying only one of the two is unread rather than counted on the
    # instruction count alone: without a core span the "core did not fall" clause is
    # vacuous and the run could only ever be a plateau.
    Reading = Data.define(:instructions, :core, :compressed) do
      def measured? = spanned?(instructions) && spanned?(core)

      def rising? = measured? && instructions.rose_by?(RISE_MARGIN) && !core.fell?

      def plateau? = measured? && instructions.flat_within?(PLATEAU_BAND)

      private

      def spanned?(span) = span.present? && span.measured?
    end

    Arm = Data.define(:label, :terminal_count, :readings, :steals, :peak_steal_rate) do
      def emerged_count = readings.size

      def measured = readings.select(&:measured?)

      def measured_count = measured.size

      def rising_count = measured.count(&:rising?)

      def plateau_count = measured.count(&:plateau?)

      def readable? = measured_count >= MIN_ARM_RUNS

      # An arm with no measured run, no blank block and no steal op has nothing this
      # reading can say about it, and is left out of the page and the report rather than
      # printed as a row of dashes.
      def reads? = measured_count.positive? || barren? || steals

      def barren? = emerged_count.zero? && terminal_count >= MIN_BARREN_RUNS

      def instructions = median_span(&:instructions)

      def core = median_span(&:core)

      def compressed = median_span(&:compressed)

      def reading
        return :barren if barren?
        return :unread unless readable?
        return :mixed if rises? && plateaus?
        return :keeps_rising if rises?
        return :plateau if plateaus?

        :neither
      end

      def rises? = half?(rising_count)

      def plateaus? = half?(plateau_count)

      # Half of the arm's measured runs, the bar DESIGN §1.3 sweep 9 sets a reading at. Two
      # measured runs is the smallest arm that reads, so a split clearing the bar both ways
      # — one run rising against one plateauing — is common enough to name: it is an arm
      # disagreeing with itself, never an arm that keeps rising. An arm clearing neither bar
      # is not that split: its runs mostly fell, and it reads neither.
      def half?(count) = count * 2 >= measured_count

      def reading_label = reading.to_s.tr("_", " ")

      def badge_class = READING_BADGES.fetch(reading)

      # A steal arm no `steal_rate` was ever sampled on is unmeasured, never the
      # theft-that-never-evolved null: the null is a claim about lineages that had the op
      # and did not use it, which a missing observable says nothing about.
      def theft
        return :no_steal_op unless steals
        return :unmeasured if peak_steal_rate.nil?
        return :never_evolved if peak_steal_rate.zero?

        :evolved
      end

      def theft_label = theft == :no_steal_op ? nil : theft.to_s.tr("_", " ")

      def cells
        [label, emerged_count, measured_count, *span_cells(instructions), *span_cells(core),
         *span_cells(compressed), rising_count, plateau_count, peak_steal_rate, theft_label, reading_label]
      end

      private

      # The arm's own span: the median across its measured runs of each run's decile
      # medians, so one run with a long tail cannot speak for the arm.
      def median_span(&block)
        spans = measured.filter_map(&block)
        return nil if spans.empty?

        Span.new(first: Findings::Median.of(spans.map(&:first)), last: Findings::Median.of(spans.map(&:last)))
      end

      def span_cells(span) = [span&.first, span&.last]
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = arms_of(sampled_runs).select(&:reads?)

    private

    def arm(label, runs)
      emerged = runs.select(&:emerged?)

      Arm.new(label: label, terminal_count: runs.count(&:terminal?),
              readings: emerged.map { |run| reading_of(run) },
              steals: runs.any? { |run| run.params[STEAL_AMOUNT].to_i.positive? },
              peak_steal_rate: peak_steal_rate_of(runs))
    end

    def reading_of(run)
      series = series_by_run.fetch(run.id, {})

      Reading.new(instructions: span_of(series[INSTRUCTIONS]), core: span_of(series[CORE]),
                  compressed: span_of(series[COMPRESSED]))
    end

    # Nothing to compare on a single reading, so a run sampled once is unmeasured rather
    # than flat. The decile is rounded up, so a run with a handful of samples reads its
    # first and last rather than nothing at all.
    def span_of(values)
      return nil if values.blank? || values.size < 2

      decile = (values.size / 10.0).ceil

      Span.new(first: Findings::Median.of(values.first(decile)), last: Findings::Median.of(values.last(decile)))
    end

    def peak_steal_rate_of(runs)
      peaks = runs.filter_map { |run| steal_peaks[run.id] }

      peaks.max&.to_f
    end

    def sampled_runs
      @sampled_runs ||= experiment.runs.where(id: sampled_run_ids)
                                  .order(:id).select(:id, :params, :status, :emergence_epoch).to_a
    end

    def steal_peaks
      @steal_peaks ||= numeric_samples(STEAL_RATE).where(run_id: sampled_run_ids)
                                                  .group(:run_id).maximum(value_of(STEAL_RATE))
    end

    # One query for every arm's series: the three readings are written into the same
    # sample, and a sample the engine reported a null for drops out of that observable's
    # series while staying in the others'.
    def series_by_run
      @series_by_run ||=
        Sample.joins(:run).where(run_id: emerged_run_ids)
              .where("samples.epoch >= runs.emergence_epoch")
              .order(:run_id, :epoch)
              .pluck(:run_id, value_of(INSTRUCTIONS), value_of(CORE), value_of(COMPRESSED))
              .group_by(&:first)
              .transform_values { |rows| series_of(rows) }
    end

    def series_of(rows)
      { INSTRUCTIONS => rows.filter_map { |row| row[1]&.to_i },
        CORE => rows.filter_map { |row| row[2]&.to_i },
        COMPRESSED => rows.filter_map { |row| row[3]&.to_i } }
    end

    def emerged_run_ids = sampled_runs.select(&:emerged?).map(&:id)

    # jsonb sorts numbers above strings and nulls, so a reading stored as anything but a
    # number is no reading here and the cast behind the guard is safe.
    def numeric_samples(observable)
      Sample.where("jsonb_typeof(samples.values -> :observable) = 'number'", observable: observable)
    end

    def value_of(observable)
      Arel.sql(ActiveRecord::Base.sanitize_sql_array(
        ["CASE WHEN jsonb_typeof(samples.values -> ?) = 'number' " \
         "THEN (samples.values ->> ?)::numeric END", observable, observable]
      ))
    end

    attr_reader :experiment
  end
end
