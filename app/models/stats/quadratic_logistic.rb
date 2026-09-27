# frozen_string_literal: true

module Stats
  # A binomial logistic regression of a success probability on x and x², logit p = b₀ + b₁x +
  # b₂x², fitted by maximum likelihood with Newton–Raphson from every coefficient at zero.
  # The data are grouped: `[[x, successes, trials], ...]`, which fits exactly as the same
  # runs one by one would. A fit that has not settled — every coefficient moving by less than
  # TOLERANCE — within ITERATIONS steps, or whose information matrix cannot be inverted, is
  # no fit: that is what a separated table does, where the likelihood has no maximum.
  class QuadraticLogistic
    TOLERANCE = 1e-10
    ITERATIONS = 100

    # `quadratic_se` is the Wald standard error of b₂ from the inverse information at the
    # maximum; `wald_p` is two-sided.
    Fit = Data.define(:intercept, :linear, :quadratic, :quadratic_se) do
      def wald_z = quadratic / quadratic_se

      def wald_p = Math.erfc(wald_z.abs / Math.sqrt(2))

      # The x where a downward parabola peaks; nil for one that does not open downward.
      def peak = quadratic.negative? ? -linear / (2 * quadratic) : nil
    end

    def self.fit(groups) = new(groups).fit

    def initialize(groups)
      @groups = groups.map { |x, successes, trials| [x.to_f, successes.to_f, trials.to_f] }
    end

    def fit
      coefficients = [0.0, 0.0, 0.0]
      ITERATIONS.times do
        gradient, information = score(coefficients)
        covariance = invert(information)
        return nil if covariance.nil?

        step = covariance.map { |row| dot(row, gradient) }
        coefficients = coefficients.zip(step).map { |value, change| value + change }
        return nil unless coefficients.all?(&:finite?)
        return settled(coefficients) if step.all? { |change| change.abs < TOLERANCE }
      end
      nil
    end

    private

    attr_reader :groups

    def settled(coefficients)
      covariance = invert(score(coefficients).last)
      return nil if covariance.nil? || !covariance[2][2].positive?

      Fit.new(intercept: coefficients[0], linear: coefficients[1], quadratic: coefficients[2],
              quadratic_se: Math.sqrt(covariance[2][2]))
    end

    # The log-likelihood's gradient and the information matrix, −∂²ℓ, at `coefficients`.
    def score(coefficients)
      gradient = [0.0, 0.0, 0.0]
      information = Array.new(3) { [0.0, 0.0, 0.0] }
      groups.each do |x, successes, trials|
        terms = [1.0, x, x * x]
        chance = 1.0 / (1.0 + Math.exp(-dot(coefficients, terms)))
        weight = trials * chance * (1.0 - chance)
        3.times do |row|
          gradient[row] += (successes - (trials * chance)) * terms[row]
          3.times { |column| information[row][column] += weight * terms[row] * terms[column] }
        end
      end
      [gradient, information]
    end

    def dot(left, right) = left.zip(right).sum { |a, b| a * b }

    # Gauss–Jordan elimination with partial pivoting; nil for a singular matrix.
    def invert(matrix)
      size = matrix.size
      rows = matrix.each_with_index.map { |row, index| row + Array.new(size) { |column| column == index ? 1.0 : 0.0 } }
      size.times do |column|
        best = pivot_row(rows, column)
        return nil if best.nil?

        rows[column], rows[best] = rows[best], rows[column]
        eliminate(rows, column)
      end
      rows.map { |row| row.drop(size) }
    end

    # The remaining row with the largest entry in `column`; nil where every one is zero.
    def pivot_row(rows, column)
      best = (column...rows.size).max_by { |row| rows[row][column].abs }
      rows[best][column].abs > 1e-12 ? best : nil
    end

    # Scales the pivot row to 1 on the diagonal and clears `column` from every other row.
    def eliminate(rows, column)
      lead = rows[column][column]
      rows[column] = rows[column].map { |value| value / lead }
      rows.each_index do |row|
        next if row == column

        factor = rows[row][column]
        rows[row] = rows[row].zip(rows[column]).map { |value, pivot_value| value - (factor * pivot_value) }
      end
    end
  end
end
