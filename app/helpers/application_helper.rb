# frozen_string_literal: true

module ApplicationHelper
  def param_value(value)
    return "—" if value.nil?

    value.is_a?(Numeric) ? Charts.format_value(value.to_f) : value.to_s
  end

  # One epoch, or a range of them (a quartile pair) collapsed when both ends coincide.
  def epoch_value(*epochs)
    return "—" if epochs.any?(&:nil?)

    epochs.map { |epoch| number_with_delimiter(epoch.round) }.uniq.join("–")
  end
end
