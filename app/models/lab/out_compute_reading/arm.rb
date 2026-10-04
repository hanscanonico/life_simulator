# frozen_string_literal: true

module Lab
  module OutComputeReading
    # One arm's children, counted, with the median of its measured children's last-decile
    # depth: the level the three level tests compare, pair by pair.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      def median_last_depth
        depths = children.select(&:level_measured?).map(&:level)
        depths.empty? ? nil : Findings::Median.of(depths)
      end

      def cells = [name, children.size, *ARM_COUNTS.map { |predicate| children.count(&predicate) }, median_last_depth]
    end
  end
end
