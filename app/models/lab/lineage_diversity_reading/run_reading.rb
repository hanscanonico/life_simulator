# frozen_string_literal: true

module Lab
  module LineageDiversityReading
    # One finished run's samples from its `emergence_epoch` on — `[[epoch, values], ...]` in
    # epoch order — read under the entry's per-run rules and the clarifications recorded
    # before any run was read (`docs/design_record.md`, 2026-09-25). A run is emerged when
    # one of them reads a numeric `replicator_share` of at least MIN_SHARE. Its deciles are
    # the first and last `ceil(n / 10)` of all `n` of those samples, cut before anything is
    # filtered, as the from-emerged reading cuts them (Lab::DescendantReading::Child); inside
    # a decile a value the engine did not report as a number drops out, and a median is
    # Findings::Median's lower middle.
    class RunReading
      # What the rules read off the samples, kept apart from them so a run's reading can be
      # cached without its samples. `decile_readings` counts the last decile's samples that
      # carry DIVERSITY_KEY as a number, `descriptive` holds the last-decile median of each
      # DESCRIPTIVE_KEYS observable, and `copy_latency_first` the first decile's.
      Reading = Data.define(:emerged, :verdict, :effective_count, :decile_readings, :descriptive,
                            :copy_latency_first) do
        def emerged? = emerged

        def measured? = emerged && verdict != :unmeasured

        def descriptive_value(key) = descriptive[key]
      end

      NOT_EMERGED = Reading.new(emerged: false, verdict: nil, effective_count: nil, decile_readings: 0,
                                descriptive: {}, copy_latency_first: nil)

      def self.read(samples) = new(samples).reading

      def initialize(samples)
        @samples = samples
      end

      def reading
        return NOT_EMERGED unless emerged?

        Reading.new(emerged: true, verdict: verdict, effective_count: effective_count,
                    decile_readings: effective_counts.size,
                    descriptive: DESCRIPTIVE_KEYS.index_with { |key| median(last_decile, key) },
                    copy_latency_first: median(first_decile, "copy_latency"))
      end

      private

      def emerged? = @samples.any? { |_, values| number?(values[SHARE_KEY]) && values[SHARE_KEY] >= MIN_SHARE }

      # :polyphyletic, :between, :monophyletic or :unmeasured.
      def verdict
        return :unmeasured if effective_count.nil?
        return :polyphyletic if effective_count >= POLYPHYLETIC
        return :monophyletic if effective_count < MONOPHYLETIC

        :between
      end

      # Fewer than MIN_DECILE_SAMPLES of the last decile's samples carrying the count leaves
      # the run unmeasured.
      def effective_count
        return nil if effective_counts.size < MIN_DECILE_SAMPLES

        Findings::Median.of(effective_counts)
      end

      def effective_counts = @effective_counts ||= numbers(last_decile, DIVERSITY_KEY)

      def decile_size = (@samples.size + 9) / 10

      def first_decile = @samples.first(decile_size)

      def last_decile = @samples.last(decile_size)

      def median(decile, key) = Findings::Median.of(numbers(decile, key))

      def numbers(decile, key) = decile.map { |_, values| values[key] }.grep(Numeric)

      def number?(value) = value.is_a?(Numeric)
    end
  end
end
