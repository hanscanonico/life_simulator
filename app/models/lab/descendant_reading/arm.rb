# frozen_string_literal: true

module Lab
  module DescendantReading
    # One treatment of the from-emerged sweep and its children
    # (Experiments::FromEmergedReadingService::ChildRow): the per-treatment counts and the
    # descriptive readings beside them.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      def terminal_count = children.count(&:terminal?)

      # A verdict of either rule, over the children sampled so far: one nothing has been
      # sampled from yet is no reading, not an unmeasured one.
      def verdict_count(verdict)
        children.count do |child|
          child.reading.sampled? && [child.reading.persistence, child.reading.complexity].include?(verdict)
        end
      end

      def read_count = children.count { |child| child.reading.persistence }

      # The share of children read for persistence that relapsed; nil with none read.
      def relapse_rate = read_count.zero? ? nil : Rational(verdict_count(:relapsed), read_count)

      def median_of(key) = Findings::Median.of(children.filter_map { |child| child.reading.last_median(key) })

      def steal_rate = treatment.priced? ? median_of(STEAL_RATE) : nil

      # The median over children, per bin of own epochs, of each child's median share there.
      def trajectory
        bins = children.map { |child| child.reading.shares_by_bin }
        bins.flat_map(&:keys).uniq.sort.map do |bin|
          [bin, Findings::Median.of(bins.filter_map { |by_bin| by_bin[bin] })]
        end
      end

      def cells
        [name, children.size, terminal_count, *VERDICTS.map { |verdict| verdict_count(verdict) }, steal_rate,
         median_of(DISTINCT_TAPES)]
      end
    end
  end
end
