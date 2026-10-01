# frozen_string_literal: true

module Stats
  # Holm's step-down correction of a family of p-values. The adjusted p of the i-th smallest
  # of m is the largest, over it and every smaller one, of (m − j + 1) · p₍ⱼ₎, capped at 1,
  # so a test is rejected at family level α exactly where its adjusted p is below α. The
  # values come back in the order they were given.
  module Holm
    def self.adjust(p_values)
      size = p_values.size
      running = 0
      adjusted = p_values.each_with_index.sort_by { |value, index| [value, index] }.each_with_index
                         .map do |(value, index), rank|
        running = ((size - rank) * value).clamp(running, 1)
        [index, running]
      end
      adjusted.sort_by(&:first).map(&:last)
    end
  end
end
