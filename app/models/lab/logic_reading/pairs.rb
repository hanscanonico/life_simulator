# frozen_string_literal: true

module Lab
  module LogicReading
    # The pairs the four tests read: a treated child against the control child of the same
    # (parent, seed), each a pair Lab::DescendantReading::Comparison tests. `treated` and
    # `control` are Experiments::LogicReadingService::ChildRow; `control` is nil where that
    # child does not exist yet. `keep_extinct` is the §5.6 sensitivity reading, which keeps
    # the pairs the replicator-share rules would leave out.
    module Pairs
      # H-capability-L, H-deep and H-stones, as Metabolism's capability pairs: measured where
      # both children carry the key's last-decile median and neither is extinct; the pair
      # favours the side whose median is higher, and equal medians tie.
      Capability = Data.define(:key, :keep_extinct, :parent_id, :seed, :treated, :control) do
        def measured?
          !control.nil? && [treated, control].all? { |child| child.capability_measured?(key, keep_extinct:) }
        end

        def favours_treatment? = measured? && treated.capability(key) > control.capability(key)

        def favours_continuation? = measured? && control.capability(key) > treated.capability(key)
      end

      # H-complexity, Lab::FromEmergedHeldout::Pairs::Survivors' rule: measured where both
      # children are measured under the complexity rule and survived, neither extinct nor
      # relapsed past the window; the pair favours the side that rises alone.
      Complexity = Data.define(:keep_extinct, :parent_id, :seed, :treated, :control) do
        def measured?
          !control.nil? && [treated, control].all? { |child| child.complexity_measured?(keep_extinct:) }
        end

        def favours_treatment? = measured? && treated.reading.rises? && !control.reading.rises?

        def favours_continuation? = measured? && control.reading.rises? && !treated.reading.rises?
      end
    end
  end
end
