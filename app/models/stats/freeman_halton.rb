# frozen_string_literal: true

module Stats
  # The Freeman–Halton extension of Fisher's exact test to a k×2 table of counts — one row
  # per arm, [emerged, not emerged] — two-sided by the same rule as Stats::FisherExact: p is
  # the total probability, under the margins, of every table no more likely than the
  # observed one. Each table's weight is the product of its rows' binomial coefficients, an
  # integer, so the comparison is an exact equality and the division happens once. It
  # enumerates every table the margins allow, which is a few thousand for four arms of
  # ninety sharing a few dozen events, and grows as the events to the power of one fewer
  # than the arms past that.
  class FreemanHalton
    def self.p_value(rows) = new(rows).p_value

    def initialize(rows)
      @sizes = rows.map(&:sum)
      @observed = rows.map(&:first)
    end

    # Nil with fewer than two rows or an empty one: an arm nobody ran to an end is not
    # compared with anything.
    def p_value
      return nil if sizes.size < 2 || !sizes.all?(&:positive?)

      threshold = observed.each_with_index.reduce(1) { |product, (count, row)| product * coefficients[row][count] }
      extreme = 0
      total = 0
      each_weight(0, observed.sum, 1) do |chance|
        total += chance
        extreme += chance if chance <= threshold
      end
      Rational(extreme, total).to_f.clamp(0.0, 1.0)
    end

    private

    attr_reader :sizes, :observed

    # C(size, 0..size) for each row, so a table's weight is one lookup per row.
    def coefficients
      @coefficients ||= sizes.map do |size|
        (1..size).each_with_object([1]) { |step, row| row << (row.last * (size - step + 1) / step) }
      end
    end

    def each_weight(row, remaining, product, &)
      if row == sizes.size - 1
        yield product * coefficients[row][remaining] if remaining <= sizes[row]
        return
      end

      (0..[remaining, sizes[row]].min).each do |count|
        each_weight(row + 1, remaining - count, product * coefficients[row][count], &)
      end
    end
  end
end
