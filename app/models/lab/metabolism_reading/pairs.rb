# frozen_string_literal: true

module Lab
  module MetabolismReading
    # The pairs H-capability and H-ladder test: a reward child against the no-reward child of
    # the same (parent, seed), each a pair Lab::DescendantReading::Comparison tests. H-complexity's
    # pairs are the held-out reading's (Lab::FromEmergedHeldout::Pairs::Survivors).
    module Pairs
      # `treated` and `control` are Experiments::MetabolismReadingService::ChildRow; `control`
      # is nil where that child does not exist yet. A pair is measured only where neither
      # child is extinct and both carry the key's last-decile median; it favours the side
      # whose median is higher, and equal medians tie.
      Capability = Data.define(:key, :parent_id, :seed, :treated, :control) do
        def measured? = !control.nil? && treated.capability_measured?(key) && control.capability_measured?(key)

        def favours_treatment? = measured? && treated.capability(key) > control.capability(key)

        def favours_continuation? = measured? && control.capability(key) > treated.capability(key)
      end
    end
  end
end
