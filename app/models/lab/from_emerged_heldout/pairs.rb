# frozen_string_literal: true

module Lab
  module FromEmergedHeldout
    # The held-out entry's two paired readings of an economy child against the continuation
    # child of the same (parent, seed), each a pair Lab::DescendantReading::Comparison tests.
    # `treated` and `control` are Experiments::FromEmergedReadingService::ChildRow; `control`
    # is nil where that child does not exist yet.
    module Pairs
      # H3-latency: the pair favours the side whose copier got faster by the larger factor, a
      # lower latency ratio; equal ratios tie.
      Latency = Data.define(:parent_id, :seed, :treated, :control) do
        def measured? = !control.nil? && treated.heldout.latency_measured? && control.heldout.latency_measured?

        def favours_treatment? = measured? && treated.heldout.latency_ratio < control.heldout.latency_ratio

        def favours_continuation? = measured? && control.heldout.latency_ratio < treated.heldout.latency_ratio
      end

      # H4-survivors: the original complexity rule, over pairs whose two children both
      # survived and were both measured.
      Survivors = Data.define(:parent_id, :seed, :treated, :control) do
        def measured? = !control.nil? && [treated, control].all? { |child| survived_measured?(child) }

        def favours_treatment? = measured? && treated.reading.rises? && !control.reading.rises?

        def favours_continuation? = measured? && control.reading.rises? && !treated.reading.rises?

        private

        def survived_measured?(child) = child.heldout.survivor? && child.reading.measured?
      end
    end
  end
end
