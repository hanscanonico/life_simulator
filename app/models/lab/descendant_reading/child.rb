# frozen_string_literal: true

module Lab
  module DescendantReading
    # One child's own samples — `[[epoch, values], ...]` at epochs above its parent epoch, in
    # epoch order — read under the entry's two per-child rules. A decile is the sweeps 9 and
    # 10 decile (Experiments::ComplexityArmsService): the first or last `ceil(n / 10)` of the
    # child's `n` own samples, cut before the self-replicating ones are picked out of it
    # (the first of the entry's clarifications, `docs/design_record.md`, 2026-09-25). A
    # median is Findings::Median's lower middle. A value the engine did not report as a
    # number drops out of its decile, as it does there.
    class Child
      # What the rules read off the samples, kept apart from them so a sweep's reading can
      # be cached without its samples.
      Reading = Data.define(:last_epoch, :persistence, :last_share, :relapse_epoch, :first_instructions,
                            :last_instructions, :complexity, :last_medians, :shares_by_bin) do
        def sampled? = !last_epoch.nil?

        def measured? = complexity != :unmeasured

        def rises? = complexity == :rises

        # A descriptive value of the last decile: `steal_rate`, `distinct_tapes`.
        def last_median(key) = last_medians[key]
      end

      # `descriptive` keys are read as last-decile medians; the share trajectory is binned
      # by `bin` epochs past `parent_epoch`, keyed by each bin's last own epoch.
      def self.read(samples, parent_epoch:, descriptive: [], bin: 1_000)
        new(samples).reading(parent_epoch: parent_epoch, descriptive: descriptive, bin: bin)
      end

      def initialize(samples)
        @samples = samples
      end

      def reading(parent_epoch:, descriptive:, bin:)
        Reading.new(last_epoch: @samples.last&.first, persistence: persistence, last_share: last_share,
                    relapse_epoch: relapse_epoch, first_instructions: first_instructions,
                    last_instructions: last_instructions, complexity: complexity,
                    last_medians: descriptive.index_with { |key| Findings::Median.of(numbers(last_decile, key)) },
                    shares_by_bin: shares_by_bin(parent_epoch, bin))
      end

      private

      # :held or :relapsed; nil for a child that never sampled a share, which the rule
      # cannot read at all.
      def persistence
        return nil if shares.empty?

        held? ? :held : :relapsed
      end

      def held? = !last_share.nil? && last_share >= HELD_SHARE && relapse_epoch.nil?

      def last_share = @last_share ||= Findings::Median.of(numbers(last_decile, SHARE_KEY))

      # The first sample of the first run of FLOOR_RUN samples below FLOOR_SHARE; nil for a
      # child that never sat there, including one that relapsed on its last decile alone.
      def relapse_epoch
        return @relapse_epoch if defined?(@relapse_epoch)

        @relapse_epoch = floor_run_start
      end

      # :rises, :plateau, :mixed or :unmeasured.
      def complexity
        first = first_instructions
        last = last_instructions
        return :unmeasured if first.nil? || last.nil?
        return :rises if Rational(last) >= Rational(first) * RISE_FACTOR.rationalize
        return :plateau if (Rational(last) - Rational(first)).abs <= Rational(first) * PLATEAU_BAND.rationalize

        :mixed
      end

      def first_instructions = @first_instructions ||= replicating_median(first_decile)

      def last_instructions = @last_instructions ||= replicating_median(last_decile)

      def shares_by_bin(parent_epoch, width)
        shares.group_by { |epoch, _| (((epoch - parent_epoch - 1) / width) + 1) * width }
              .transform_values { |pairs| Findings::Median.of(pairs.map(&:last)) }
      end

      def decile_size = (@samples.size + 9) / 10

      def first_decile = @samples.first(decile_size)

      def last_decile = @samples.last(decile_size)

      def shares
        @shares ||= @samples.filter_map { |epoch, values| [epoch, values[SHARE_KEY]] if number?(values[SHARE_KEY]) }
      end

      def floor_run_start
        run = []
        shares.each do |epoch, share|
          run = share < FLOOR_SHARE ? [*run, epoch] : []
          return run.first if run.size >= FLOOR_RUN
        end
        nil
      end

      # Fewer than MIN_DECILE_SAMPLES self-replicating samples leaves the decile unread.
      def replicating_median(decile)
        counts = decile.filter_map do |_, values|
          values[COMPLEXITY_KEY] if values[REPLICATING_KEY] == true && number?(values[COMPLEXITY_KEY])
        end
        counts.size < MIN_DECILE_SAMPLES ? nil : Findings::Median.of(counts)
      end

      def numbers(decile, key) = decile.filter_map { |_, values| values[key] if number?(values[key]) }

      def number?(value) = value.is_a?(Numeric)
    end
  end
end
