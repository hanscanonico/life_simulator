# frozen_string_literal: true

module Findings
  # One median convention for every finding page: the lower of the two middle values on an
  # even count, never an interpolation. The distributions these surveys read are a handful
  # of seeds wide, and an averaged middle pair would print a resolution they do not have.
  module Median
    def self.of(values)
      return nil if values.empty?

      sorted = values.sort
      sorted[(sorted.size - 1) / 2]
    end
  end
end
