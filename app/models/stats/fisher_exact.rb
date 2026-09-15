# frozen_string_literal: true

module Stats
  # Fisher's exact test on a 2×2 table of counts, two-sided by the conventional rule: the
  # p-value is the total hypergeometric probability of every table with the same margins
  # that is no more likely than the observed one. The arms these findings compare are ten
  # seeds wide with none or one emergence in most of them, which is exactly where a
  # chi-square approximation stops being one, so the sum is taken in exact rationals and
  # converted only at the end: a table as likely as the observed one is then recognised by
  # an exact equality, where floats would need the relative slack R's `fisher.test` carries.
  class FisherExact
    def self.two_sided(table) = new(table).two_sided

    def initialize(table)
      @observed, @row_one_rest, @row_two_observed, @row_two_rest = table.flatten
    end

    # Nil rather than a number when either row is empty: an arm nobody ran to an end has
    # not been tested against the control, and a test on it would print a certainty the
    # table does not hold.
    def two_sided
      return nil unless row_one.positive? && row_two.positive?

      support.map { |count| probability(count) }.select { |chance| chance <= threshold }.sum.to_f.clamp(0.0, 1.0)
    end

    private

    attr_reader :observed, :row_one_rest, :row_two_observed, :row_two_rest

    def row_one = observed + row_one_rest

    def row_two = row_two_observed + row_two_rest

    def column_one = observed + row_two_observed

    def total = row_one + row_two

    def support = ([column_one - row_two, 0].max..[row_one, column_one].min)

    def threshold = @threshold ||= probability(observed)

    def probability(count)
      Rational(choose(row_one, count) * choose(row_two, column_one - count), choose(total, column_one))
    end

    def choose(outer, inner) = (0...inner).reduce(1) { |product, step| product * (outer - step) / (step + 1) }
  end
end
