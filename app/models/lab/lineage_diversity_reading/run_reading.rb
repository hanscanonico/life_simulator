# frozen_string_literal: true

module Lab
  module LineageDiversityReading
    # One finished run's samples from its `emergence_epoch` on — `[[epoch, values], ...]` in
    # epoch order — read under the entry's per-run rules. A run is emerged when one of them
    # reads a numeric `replicator_share` of at least MIN_SHARE. The samples read for its class
    # are those carrying DIVERSITY_KEY as a number: its last decile is the last `ceil(n / 10)`
    # of those `n`, as the from-emerged reading cuts one (Lab::DescendantReading::Child), and
    # a median is Findings::Median's lower middle.
    class RunReading
      # What the rules read off the samples, kept apart from them so a run's reading can be
      # cached without its samples. `descriptive` holds the last-decile median of each
      # DESCRIPTIVE_KEYS observable, and `copy_latency_first` the first decile's.
      Reading = Data.define(:emerged, :verdict, :effective_count, :decile_size, :descriptive,
                            :copy_latency_first) do
        def emerged? = emerged

        def measured? = emerged && verdict != :unmeasured

        def descriptive_value(key) = descriptive[key]
      end

      NOT_EMERGED = Reading.new(emerged: false, verdict: nil, effective_count: nil, decile_size: 0, descriptive: {},
                                copy_latency_first: nil)

      def self.read(samples) = new(samples).reading

      def initialize(samples)
        @samples = samples
      end

      def reading
        return NOT_EMERGED unless emerged?

        Reading.new(emerged: true, verdict: verdict, effective_count: effective_count, decile_size: last_decile.size,
                    descriptive: DESCRIPTIVE_KEYS.index_with { |key| median(last_decile, key) },
                    copy_latency_first: median(diversity_samples.first(decile_size), "copy_latency"))
      end

      private

      def emerged? = @samples.any? { |_, values| number?(values[SHARE_KEY]) && values[SHARE_KEY] >= MIN_SHARE }

      # :polyphyletic, :between, :monophyletic or :unmeasured.
      def verdict
        return :unmeasured if last_decile.size < MIN_DECILE_SAMPLES
        return :polyphyletic if effective_count >= POLYPHYLETIC
        return :monophyletic if effective_count < MONOPHYLETIC

        :between
      end

      def effective_count
        return nil if last_decile.size < MIN_DECILE_SAMPLES

        @effective_count ||= median(last_decile, DIVERSITY_KEY)
      end

      def diversity_samples = @diversity_samples ||= @samples.select { |_, values| number?(values[DIVERSITY_KEY]) }

      def decile_size = (diversity_samples.size + 9) / 10

      def last_decile = @last_decile ||= diversity_samples.last(decile_size)

      def median(decile, key) = Findings::Median.of(decile.map { |_, values| values[key] }.grep(Numeric))

      def number?(value) = value.is_a?(Numeric)
    end
  end
end
