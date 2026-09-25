# frozen_string_literal: true

module Lab
  module LineageDiversityReading
    # The locked hypothesis over the sweep's arms, given the trend's permutation `p_value`
    # (nil with fewer than MIN_READ_ARMS read arms, where no trend is tested). Shown needs
    # the trend and a polyphyletic median at the read arm of shortest reach; refuted needs
    # MIN_READ_ARMS read arms and every measured emerged run of the sweep monophyletic. The
    # two cannot both hold: a polyphyletic median is a polyphyletic run.
    Hypothesis = Data.define(:arms, :p_value) do
      # The read arms in RADIUS_ORDER, the order the trend predicts them to rise.
      def read_arms = RADIUS_ORDER.filter_map { |radius| arms.find { |arm| arm.radius == radius && arm.read? } }

      def unread_arms = arms.reject(&:read?)

      def testable? = read_arms.size >= MIN_READ_ARMS

      def trend? = !p_value.nil? && p_value < TREND_LEVEL.rationalize

      def shortest_read_arm = read_arms.last

      def polyphyletic_at_shortest? = !shortest_read_arm.nil? && shortest_read_arm.effective_count >= POLYPHYLETIC

      def shown? = trend? && polyphyletic_at_shortest?

      def refuted?
        verdicts = arms.flat_map(&:measured).map { |row| row.reading.verdict }
        testable? && verdicts.any? && verdicts.all?(:monophyletic)
      end

      def outcome
        return :shown if shown?
        return :refuted if refuted?

        :neither
      end

      def outcome_label = outcome == :neither ? "neither shown nor refuted" : outcome.to_s

      def badge_class = { shown: "badge-success", refuted: "badge-error" }.fetch(outcome, "badge-info")

      # A significant trend among worlds that do not read polyphyletic at the shortest reach
      # is reported as a trend, not as the hypothesis.
      def trend_without_polyphyly? = trend? && !polyphyletic_at_shortest?

      def statistic = testable? ? Stats::JonckheereTerpstra.new(read_arms.map(&:values)).statistic : nil

      def line
        parts = ["hypothesis #{outcome_label}", trend_line]
        parts << "a trend, not the hypothesis: the shortest read reach is not polyphyletic" if trend_without_polyphyly?
        parts << "unread: #{unread_arms.map(&:label).join(', ')}" if unread_arms.any?
        parts.join("; ")
      end

      private

      def trend_line
        return "no trend test: fewer than #{MIN_READ_ARMS} read arms" unless testable?

        "trend p = #{format('%.5f', p_value)} over #{read_arms.map(&:label).join(' < ')}, JT = #{statistic.to_f}"
      end
    end
  end
end
