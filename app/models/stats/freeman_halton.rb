# frozen_string_literal: true

module Stats
  # The Freeman–Halton extension of Fisher's exact test to a k×2 table of counts — one row
  # per arm, [emerged, not emerged] — two-sided by the same rule as Stats::FisherExact: p is
  # the total probability, under the margins, of every table no more likely than the
  # observed one. Each table's weight is the product of its rows' binomial coefficients, an
  # integer, so the comparison is an exact equality and the division happens once. It
  # enumerates every table the margins allow, which is a few thousand for four arms of
  # ninety sharing a few dozen events, and grows fast past that.
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

      threshold = weight(observed)
      extreme = 0
      total = 0
      each_table(0, observed.sum, []) do |table|
        chance = weight(table)
        total += chance
        extreme += chance if chance <= threshold
      end
      Rational(extreme, total).to_f.clamp(0.0, 1.0)
    end

    private

    attr_reader :sizes, :observed

    def each_table(row, remaining, prefix, &)
      if row == sizes.size - 1
        yield [*prefix, remaining] if remaining <= sizes[row]
        return
      end

      (0..[remaining, sizes[row]].min).each { |count| each_table(row + 1, remaining - count, [*prefix, count], &) }
    end

    def weight(table) = table.zip(sizes).reduce(1) { |product, (count, size)| product * choose(size, count) }

    def choose(outer, inner) = (0...inner).reduce(1) { |product, step| product * (outer - step) / (step + 1) }
  end
end
