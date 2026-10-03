# frozen_string_literal: true

module Lab
  module ToplessRiseReading
    # A rise child against the control child of the same parent, a pair
    # Lab::DescendantReading::Comparison tests: measured where both children carry both
    # deciles' medians and neither is extinct, unless `keep_extinct`; the pair favours the side
    # that rises late alone. `treated` and `control` are
    # Experiments::ToplessRiseReadingService::ChildRow; `control` is nil where that child does
    # not exist yet.
    Pair = Data.define(:keep_extinct, :parent_id, :seed, :treated, :control) do
      def measured?
        !control.nil? && [treated, control].all? { |child| child.rise_measured?(keep_extinct:) }
      end

      def favours_treatment? = measured? && treated.rises? && !control.rises?

      def favours_continuation? = measured? && control.rises? && !treated.rises?
    end
  end
end
