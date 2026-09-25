# frozen_string_literal: true

module Experiments
  # The complexity reading of DESIGN §1.3 sweeps 9 and 10, arm by arm: does
  # the dominant tape keep getting more complicated where energy is a contested stock or
  # where only one partner's code runs, or does it plateau as it did on every substrate
  # before it?
  #
  # Taken on emerged runs only — a crossing the census or the copy rate confirmed, not
  # every crossing the detector flagged. Per run it compares the median of the last decile
  # of the post-crossing samples against the median of the first decile: a rise of at least
  # RISE_MARGIN in `dominant_instruction_count` with the conserved core not falling in bytes
  # over the same span is a run that keeps rising, and a last decile within PLATEAU_BAND of
  # the first is a run that plateaued. The core clause is absolute, and a run is measured on
  # its instruction count alone — the post-hoc amendment of `docs/design_record.md`,
  # 2026-09-21 — so every arm row carries `pre_registered_unmeasured_count` beside it: the
  # runs the pre-registered rule would have dropped. `dominant_compressed_len` is carried beside them and decides
  # nothing: it saturates at the tape cap plus zlib's envelope (`docs/design_record.md`,
  # 2026-09-16). An arm reads with MIN_ARM_RUNS measured runs, or with a blank block of
  # MIN_BARREN_RUNS; a steal arm whose `steal_rate` never left zero reads as theft that
  # never evolved rather than as theft that does not help, and one no `steal_rate` was ever
  # sampled on reads as theft unmeasured rather than as theft that never evolved.
  # `distinct_lineages` rides beside them for sweep 10's secondary reading — an arms race
  # shows as a late-run lineage count above the control's at the same cap — and decides
  # nothing on its own.
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
    LINEAGES = "distinct_lineages"
    SERIES = [INSTRUCTIONS, CORE, COMPRESSED, LINEAGES].freeze
    STEAL_RATE = "steal_rate"
    STEAL_AMOUNT = "steal_amount"

    RISE_MARGIN = 0.2
    PLATEAU_BAND = 0.1
    MIN_ARM_RUNS = 2
    MIN_BARREN_RUNS = 10

    COLUMNS = %w[
      arm emerged measured pre_registered_unmeasured instructions_first instructions_last core_first core_last
      compressed_first compressed_last lineages_first lineages_last rising plateau
      peak_steal_rate theft reading
    ].freeze

    # What is read of one run's samples: the spans of a run that emerged, and its peak
    # `steal_rate`.
    RunReading = Data.define(:spans, :steal_peak)

    # A run's reading is this file's as much as its samples', and the Data it is held in
    # stops loading once a member is added. Digested once per boot.
    READING_VERSION = Digest::SHA256.hexdigest(
      Rails.root.join("app/services/experiments/complexity_arms_service.rb").binread
    )

    READING_BADGES = { keeps_rising: "badge-success", plateau: "badge-warning", mixed: "badge-info",
                       neither: "badge-error", unread: "badge-info", barren: "badge-error" }.freeze

    # The two decile medians of one observable over one run's post-crossing samples.
    Span = Data.define(:first, :last) do
      # A span starting at zero has no ratio at all: nothing rose or plateaued by a
      # percentage of nothing, so a percentage of it is unread rather than flat or infinite.
      def ratio? = !first.zero?

      def growth = last / first.to_f

      def rose_by?(margin) = ratio? && growth >= 1 + margin

      # Absolute, not a ratio: a core of zero bytes that stays at zero has not fallen
      # (`docs/design_record.md`, 2026-09-21).
      def fell? = last < first

      def flat_within?(band) = ratio? && growth.between?(1 - band, 1 + band)
    end

    # The amended rule of 2026-09-21 reads a run on its instruction count: a run whose
    # first-decile median of `dominant_instruction_count` is nonzero is measured, and its
    # conserved core is compared in bytes rather than as a ratio, so a core that reads zero
    # at both ends satisfies "the core did not fall". A run carrying no core sample at all
    # over the span is still unread: there the clause cannot be read at all, and the run
    # could only ever be a plateau. `pre_registered_measured?` keeps the pre-registered
    # reading beside the amended one, as that entry requires.
    Reading = Data.define(:instructions, :core, :compressed, :lineages) do
      def measured? = spanned?(instructions) && instructions.ratio? && spanned?(core)

      def pre_registered_measured? = measured? && core.ratio?

      def rising? = measured? && instructions.rose_by?(RISE_MARGIN) && !core.fell?

      def plateau? = measured? && instructions.flat_within?(PLATEAU_BAND)

      private

      def spanned?(span) = span.present?
    end

    Arm = Data.define(:label, :terminal_count, :readings, :steals, :peak_steal_rate) do
      def emerged_count = readings.size

      def measured = readings.select(&:measured?)

      def measured_count = measured.size

      def rising_count = measured.count(&:rising?)

      def plateau_count = measured.count(&:plateau?)

      # What the pre-registered rule of DESIGN §1.3 read here: the runs it would have
      # dropped as unmeasured because their conserved core starts at zero bytes, so the
      # amended reading is never printed without it (`docs/design_record.md`, 2026-09-21).
      def pre_registered_unmeasured_count = measured.count { |reading| !reading.pre_registered_measured? }

      def readable? = measured_count >= MIN_ARM_RUNS

      # An arm with no measured run, no blank block and no steal op has nothing this
      # reading can say about it, and is left out of the page and the report rather than
      # printed as a row of dashes.
      def reads? = measured_count.positive? || barren? || steals

      def barren? = emerged_count.zero? && terminal_count >= MIN_BARREN_RUNS

      def instructions = median_span(&:instructions)

      def core = median_span(&:core)

      def compressed = median_span(&:compressed)

      def lineages = median_span(&:lineages)

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
        [label, emerged_count, measured_count, pre_registered_unmeasured_count,
         *span_cells(instructions), *span_cells(core),
         *span_cells(compressed), *span_cells(lineages), rising_count, plateau_count,
         peak_steal_rate, theft_label, reading_label]
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
      spans = run_readings.fetch(run.id).spans

      Reading.new(instructions: spans[INSTRUCTIONS], core: spans[CORE], compressed: spans[COMPRESSED],
                  lineages: spans[LINEAGES])
    end

    def peak_steal_rate_of(runs)
      peaks = runs.filter_map { |run| run_readings.fetch(run.id).steal_peak }

      peaks.max&.to_f
    end

    def sampled_runs
      @sampled_runs ||= experiment.runs.where(id: sampled_run_ids)
                                  .order(:id).select(:id, :params, :status, :emergence_epoch, :updated_at).to_a
    end

    # A terminal run's samples never change, so what is read of them is held per run, keyed
    # on the run as it stands, and a view while the sweep runs reads again only the runs
    # still under way: the two passes over every sample cost the from-emerged page 2.6 s
    # on every view while any of its children ran.
    def run_readings
      @run_readings ||= begin
        terminal = sampled_runs.select(&:terminal?).index_by { |run| run_key(run) }
        held = held_readings(terminal)
        read = read_runs(sampled_runs.reject { |run| held.key?(run.id) })
        written = terminal.select { |_, run| read.key?(run.id) }.transform_values { |run| read.fetch(run.id) }
        Rails.cache.write_multi(written) if written.any?
        held.merge(read)
      end
    end

    def held_readings(runs_by_key)
      return {} if runs_by_key.empty?

      Rails.cache.read_multi(*runs_by_key.keys).transform_keys { |key| runs_by_key.fetch(key).id }
    end

    def run_key(run)
      ["experiments/complexity_arms/run", READING_VERSION, run.id, run.status, run.emergence_epoch,
       run.updated_at.iso8601(6)]
    end

    def read_runs(runs)
      return {} if runs.empty?

      spans = read_spans(runs.select(&:emerged?).map(&:id))
      peaks = steal_peaks(runs.map(&:id))
      runs.to_h { |run| [run.id, RunReading.new(spans: spans.fetch(run.id, {}), steal_peak: peaks[run.id])] }
    end

    # A run no `steal_rate` was sampled on groups to a null peak, which drops out like a
    # missing one. The type test sits inside the aggregate rather than in a WHERE: as a
    # filter the planner took it for a rare row and sorted the sweep's samples to disk on
    # the way to the group, ten times the cost of hashing them (issue #236).
    def steal_peaks(run_ids) = Sample.where(run_id: run_ids).group(:run_id).maximum(value_of(STEAL_RATE))

    # The four spans of every emerged run, reduced in Postgres so no sample leaves the
    # database: one statement for the runs, where one per run cost the page a round trip
    # each and every post-crossing sample held in Ruby (issues #226, #236).
    def read_spans(emerged_ids)
      return {} if emerged_ids.empty?

      Sample.connection.select_all(spans_sql(emerged_ids)).cast_values
            .each_with_object({}) do |(run_id, observable, first, last), spans|
        (spans[run_id] ||= {})[observable] = Span.new(first: first.to_i, last: last.to_i)
      end
    end

    # The rule the Ruby reading had, term for term. A sample the engine reported a null or
    # a non-number for drops out of that observable's series only, and each reading is
    # truncated to an integer as `to_i` did. A series of fewer than two readings has no
    # span. The decile is `ceil(n / 10)` readings in epoch order, and a decile's median is
    # Findings::Median's lower middle: `percentile_disc(0.5)` returns the reading at
    # position `ceil(k / 2)` of `k` sorted, which is the 0-based `(k - 1) / 2` Median reads.
    def spans_sql(run_ids)
      ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, SERIES, run_ids])
        WITH readings AS (
          SELECT samples.run_id, series.observable, samples.epoch,
                 trunc((samples.values ->> series.observable)::numeric) AS value
          FROM samples
          JOIN runs ON runs.id = samples.run_id
          CROSS JOIN unnest(ARRAY[?]::text[]) AS series(observable)
          WHERE runs.id IN (?) AND samples.epoch >= runs.emergence_epoch
            AND jsonb_typeof(samples.values -> series.observable) = 'number'
        ), ranked AS (
          SELECT run_id, observable, value,
                 row_number() OVER (PARTITION BY run_id, observable ORDER BY epoch) AS position,
                 count(*) OVER (PARTITION BY run_id, observable) AS size
          FROM readings
        )
        SELECT run_id, observable,
               percentile_disc(0.5) WITHIN GROUP (ORDER BY value) FILTER (WHERE position <= (size + 9) / 10),
               percentile_disc(0.5) WITHIN GROUP (ORDER BY value) FILTER (WHERE position > size - (size + 9) / 10)
        FROM ranked
        WHERE size >= 2
        GROUP BY run_id, observable
      SQL
    end

    # jsonb sorts numbers above strings and nulls, so a reading stored as anything but a
    # number is no reading here and the cast behind the guard is safe.
    def value_of(observable)
      Arel.sql(ActiveRecord::Base.sanitize_sql_array(
        ["CASE WHEN jsonb_typeof(samples.values -> ?) = 'number' " \
         "THEN (samples.values ->> ?)::numeric END", observable, observable]
      ))
    end

    attr_reader :experiment
  end
end
