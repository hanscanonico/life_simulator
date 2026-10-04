# frozen_string_literal: true

module Lab
  module OutComputeReading
    # The pairs the five tests read: the out-compute child against the control child of the
    # same (parent, seed), each a pair Lab::DescendantReading::Comparison tests. `treated` and
    # `control` are Experiments::OutComputeReadingService::ChildRow; `control` is nil where that
    # child does not exist yet. `keep_extinct` keeps the pairs of extinct children.
    module Pairs
      # H-endogenous, H-ratchet and H-driven, as Logic's capability pairs: measured where both
      # children carry a last-decile median `logic_depth_max` and neither is extinct; the pair
      # favours the side whose median is higher, and equal medians tie.
      Level = Data.define(:keep_extinct, :parent_id, :seed, :treated, :control) do
        def measured?
          !control.nil? && [treated, control].all? { |child| child.level_measured?(keep_extinct:) }
        end

        def favours_treatment? = measured? && treated.level > control.level

        def favours_continuation? = measured? && control.level > treated.level
      end

      # H-rise-unassisted on `logic_depth_max` (`reading` :depth) and H-repertoire on
      # `logic_depth_classes` (:classes), as topless-rise's pairs: measured where both children
      # carry both deciles' medians of the key and neither is extinct; the pair favours the
      # side that rises late alone.
      Rise = Data.define(:reading, :keep_extinct, :parent_id, :seed, :treated, :control) do
        def measured?
          !control.nil? && [treated, control].all? { |child| child.rise_measured?(reading, keep_extinct:) }
        end

        def favours_treatment? = measured? && rises?(treated) && !rises?(control)

        def favours_continuation? = measured? && rises?(control) && !rises?(treated)

        private

        def rises?(child) = child.public_send(reading).rises?
      end
    end
  end
end
