# frozen_string_literal: true

module Lab
  module ReachCap128Reading
    # One arm of the comparison and its runs (Experiments::ReachCap128ReadingService::RunRow).
    # A run is counted once it has finished and the readings pass has read every world it
    # kept: before that it may yet emerge, or emerge without a reading to show it.
    Arm = Data.define(:label, :rows) do
      def finished = rows.count(&:finished?)

      def counted = rows.count(&:counted?)

      def emerged = emerged_rows.size

      def counted? = counted.positive?

      # An exact rational, so the two arms' rates compare exactly; nil before any run counts.
      def rate = counted? ? Rational(emerged, counted) : nil

      def emerged_rows = rows.select { |row| row.emerged == true }

      def median_emergence_epoch = median(&:emergence_epoch)

      def median_terminal_share = median(&:terminal_share)

      def median_raw_len = median(&:dominant_raw_len)

      def median_instruction_count = median(&:dominant_instruction_count)

      def self_replicating_dominant = emerged_rows.count { |row| row.dominant_self_replicates == true }

      def eligible_parents = emerged_rows.count(&:eligible_parent?)

      def cells
        [label, rows.size, finished, counted, emerged, rate&.to_f, median_emergence_epoch, median_terminal_share,
         median_raw_len, median_instruction_count, self_replicating_dominant, eligible_parents]
      end

      private

      def median(&) = Findings::Median.of(emerged_rows.filter_map(&).grep(Numeric))
    end
  end
end
