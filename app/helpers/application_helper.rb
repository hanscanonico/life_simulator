# frozen_string_literal: true

module ApplicationHelper
  DEFAULT_DESCRIPTION = "A research instrument for the spontaneous emergence of self-replicators " \
                        "in a spatial program soup."

  def page_title
    [content_for(:title), "Life Simulator"].compact.join(" — ")
  end

  def page_description
    content_for(:description) || DEFAULT_DESCRIPTION
  end

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
