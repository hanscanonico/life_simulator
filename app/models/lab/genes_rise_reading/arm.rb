# frozen_string_literal: true

module Lab
  module GenesRiseReading
    # One arm's children, counted, with the median of its measured children's last-decile
    # `logic_depth_classes`.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      def median_last_classes
        classes = children.select(&:classes_measured?).map { |child| child.classes.last }
        classes.empty? ? nil : Findings::Median.of(classes)
      end

      def cells = [name, children.size, *ARM_COUNTS.map { |predicate| children.count(&predicate) }, median_last_classes]
    end
  end
end
