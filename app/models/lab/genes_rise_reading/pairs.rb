# frozen_string_literal: true

module Lab
  module GenesRiseReading
    # The pairs the five tests read: the count child against the control child of the same
    # (parent, seed), each a pair Lab::DescendantReading::Comparison tests. `treated` and
    # `control` are Experiments::GenesRiseReadingService::ChildRow; `control` is nil where that
    # child does not exist yet. `keep_extinct` keeps the pairs of extinct children.
    module Pairs
      # H-rise and H-shadow on `logic_depth_classes` (`reading` :classes), H-rise-genes on
      # `genes_essential_held` (:genes) and H-driven on the offline minimum (:minimum):
      # measured where both children carry the reading and neither is extinct; the pair
      # favours the side that rises late alone.
      LateRise = Data.define(:reading, :keep_extinct, :parent_id, :seed, :treated, :control) do
        def measured?
          !control.nil? && [treated, control].all? { |child| child.measured?(reading, keep_extinct:) }
        end

        def favours_treatment? = measured? && rises?(treated) && !rises?(control)

        def favours_continuation? = measured? && rises?(control) && !rises?(treated)

        private

        def rises?(child) = child.public_send(reading).late_rise?
      end

      # H-room, paired by parent: measured where both children carry a final-quarter gain and
      # neither is extinct; the pair favours the larger gain, and equal gains tie.
      Room = Data.define(:keep_extinct, :parent_id, :seed, :treated, :control) do
        def measured?
          !control.nil? && [treated, control].all? { |child| child.measured?(:room, keep_extinct:) }
        end

        def favours_treatment? = measured? && treated.room.gain > control.room.gain

        def favours_continuation? = measured? && control.room.gain > treated.room.gain
      end
    end
  end
end
