# frozen_string_literal: true

module ApplicationHelper
  def param_value(value)
    return "—" if value.nil?

    value.is_a?(Numeric) ? Charts.format_value(value.to_f) : value.to_s
  end
end
