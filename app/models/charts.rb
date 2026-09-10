# frozen_string_literal: true

# Server-rendered SVG charts (DESIGN.md §2: a small presenter + partial, no chart
# library). The classes here are value objects: they turn data into pixel geometry and a
# partial draws it.
module Charts
  def self.format_value(value)
    return "0" if value.zero?
    return value.round.to_s if value.abs >= 1 && (value.abs < 1e6) && (value % 1).zero?

    format("%.3g", value)
  end
end
