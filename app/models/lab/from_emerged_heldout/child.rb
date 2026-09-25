# frozen_string_literal: true

module Lab
  module FromEmergedHeldout
    # One child's own samples — `[[epoch, values], ...]` above its parent epoch, in epoch
    # order — read under the held-out entry's per-child rules, beside the original reading
    # (Lab::DescendantReading::Child) whose last-decile share decides extinction. Past the
    # settling window, a decile is the first or last `ceil(n / 10)` of the `n` samples that
    # carry `copy_latency` as a number, and a median is Findings::Median's lower middle.
    class Child
      # `read` is false for a child that never sampled a share: no rule reads it.
      Reading = Data.define(:read, :extinct, :settled_relapse_epoch, :first_latency, :last_latency) do
        # Nil for an extinct or unread child, one short of samples in either decile, or one
        # whose first decile reads a zero latency.
        def latency_ratio
          return nil if !read || extinct || first_latency.nil? || last_latency.nil? || first_latency.zero?

          Rational(last_latency) / Rational(first_latency)
        end

        def latency_measured? = !latency_ratio.nil?

        # Neither extinct nor relapsed past the window: the pairs H4-survivors reads.
        def survivor? = read && !extinct && settled_relapse_epoch.nil?
      end

      def self.read(samples, parent_epoch:, last_share:)
        new(samples, parent_epoch: parent_epoch).reading(last_share)
      end

      def initialize(samples, parent_epoch:)
        @settled = samples.select { |epoch, _| epoch > parent_epoch + SETTLING_WINDOW }
      end

      def reading(last_share)
        Reading.new(read: !last_share.nil?, extinct: !last_share.nil? && last_share < EXTINCT_SHARE,
                    settled_relapse_epoch: settled_relapse_epoch,
                    first_latency: latency_median(latencies.first(decile)),
                    last_latency: latency_median(latencies.last(decile)))
      end

      private

      def settled_relapse_epoch
        run = []
        @settled.each do |epoch, values|
          share = values[DescendantReading::SHARE_KEY]
          next unless share.is_a?(Numeric)

          run = share < RELAPSE_SHARE ? [*run, epoch] : []
          return run.first if run.size >= RELAPSE_RUN
        end
        nil
      end

      def latencies
        @latencies ||= @settled.filter_map { |_, values| values[LATENCY_KEY] if values[LATENCY_KEY].is_a?(Numeric) }
      end

      def decile = (latencies.size + 9) / 10

      def latency_median(values) = values.size < MIN_DECILE_SAMPLES ? nil : Findings::Median.of(values)
    end
  end
end
