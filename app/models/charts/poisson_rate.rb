# frozen_string_literal: true

module Charts
  # An occurrence rate and its exact 95% interval: `events` emergences seen over
  # `exposure` run-epochs at risk.
  #
  # The bounds invert the Poisson distribution (the Garwood interval) instead of leaning
  # on a normal approximation, which is wrong at the counts a sweep produces: an arm with
  # two events — or with none at all, where the interval is still one-sided and finite.
  class PoissonRate
    CONFIDENCE = 0.95
    # Bisection on a double converges long before this; the bound is a guard, not a knob.
    ITERATIONS = 80
    MAX_MEAN = 1e12

    Interval = Data.define(:value, :lower, :upper)

    def initialize(events:, exposure:, confidence: CONFIDENCE)
      @events = events.to_i
      @exposure = exposure.to_f
      @tail = (1 - confidence) / 2
    end

    attr_reader :events, :exposure

    # Per one epoch at risk. Nil with no exposure: no run has been observed, so there is
    # no rate to report — not a rate of zero.
    def value = rate(@events.to_f)

    def lower = rate(lower_mean)

    def upper = rate(upper_mean)

    # The same rate counted over a longer unit, e.g. `per(10_000)` for "per 10^4 epochs".
    def per(epochs)
      Interval.new(value: scale(value, epochs), lower: scale(lower, epochs), upper: scale(upper, epochs))
    end

    private

    def scale(rate, epochs) = rate && (rate * epochs)

    def rate(mean)
      return nil unless @exposure.positive?

      mean / @exposure
    end

    # The mean for which seeing this many events or more is exactly the lower tail.
    def lower_mean
      return 0.0 if @events.zero?

      solve { |mean| (1 - cdf(mean, @events - 1)) - @tail }
    end

    # The mean for which seeing this many events or fewer is exactly the lower tail.
    def upper_mean = solve { |mean| @tail - cdf(mean, @events) }

    def cdf(mean, count)
      return 1.0 if mean <= 0

      (0..count).sum { |i| Math.exp(-mean + (i * Math.log(mean)) - Math.lgamma(i + 1).first) }.clamp(0.0, 1.0)
    end

    # Both tails are monotonically increasing in the mean, so a bracket found by doubling
    # and then halved to convergence is enough.
    def solve
      low = 0.0
      high = 1.0
      high *= 2 while yield(high).negative? && high < MAX_MEAN
      ITERATIONS.times do
        mid = (low + high) / 2
        yield(mid).negative? ? low = mid : high = mid
      end
      (low + high) / 2
    end
  end
end
