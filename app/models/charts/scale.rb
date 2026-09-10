# frozen_string_literal: true

module Charts
  # Maps data values onto pixels along one axis, linearly or by decade.
  #
  # A log axis has to survive the mutation-rate sweep, whose grid contains 0 alongside
  # 2^-16..2^-8: a value that cannot be logged is parked one decade below the smallest
  # positive value, which is what makes the zero-mutation control visible on the same
  # chart as the rest.
  class Scale
    NICE_STEPS = [1.0, 2.0, 2.5, 5.0, 10.0].freeze
    DEFAULT_TICKS = 5

    Tick = Data.define(:value, :position) do
      def label = Charts.format_value(value)
    end

    def initialize(values:, length:, log: false, flip: false)
      @length = length.to_f
      @flip = flip
      @values = Array(values).map(&:to_f)
      @log = log && @values.any?(&:positive?)
      @zero_slot = @log && @values.any? { |value| !value.positive? }
      assign_bounds
    end

    attr_reader :min, :max, :length

    def log? = @log
    def zero_slot? = @zero_slot

    def position(value)
      along(fraction(value.to_f))
    end

    def ticks(count: DEFAULT_TICKS)
      values = log? ? log_tick_values : linear_tick_values(count)
      values.map { |value| Tick.new(value: value, position: position(value)) }
    end

    private

    def assign_bounds
      positive = @values.select(&:positive?)
      @min = (log? ? positive.min : @values.min) || 0.0
      @max = (log? ? positive.max : @values.max) || 0.0
      @min /= 10 if zero_slot?
      pad_degenerate
    end

    def pad_degenerate
      return if @max > @min

      if log?
        @max = @min * 10
      else
        margin = @max.zero? ? 1.0 : @max.abs * 0.1
        @min -= margin
        @max += margin
      end
    end

    def fraction(value)
      return 0.0 if log? && !value.positive?

      span = log? ? Math.log10(@max) - Math.log10(@min) : @max - @min
      offset = log? ? Math.log10(value) - Math.log10(@min) : value - @min
      (offset / span).clamp(0.0, 1.0)
    end

    def along(fraction)
      @flip ? @length * (1 - fraction) : @length * fraction
    end

    def log_tick_values
      lowest = Math.log10(@min).round(9).ceil
      highest = Math.log10(@max).round(9).floor
      decades = (lowest..highest).map { |exponent| 10.0**exponent }
      # The bottom of a zero-slot axis belongs to the zero tick; a decade there would
      # print a second label on the same pixel.
      decades = decades.drop(1) if zero_slot? && decades.first && decades.first <= @min * 1.000001
      decades = [@min, @max] if decades.size < 2 && !zero_slot?
      zero_slot? ? [0.0, *decades] : decades
    end

    def linear_tick_values(count)
      step = nice_step((@max - @min) / count)
      first = (@min / step).ceil * step
      first.step(@max + (step / 1000), step).map { |value| (value / step).round * step }
    end

    def nice_step(rough)
      magnitude = 10.0**Math.log10(rough.abs).floor
      NICE_STEPS.find { |candidate| candidate * magnitude >= rough } * magnitude
    end
  end
end
