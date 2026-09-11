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

  # A hazard, already scaled to its reporting unit. Three significant figures keep an arm
  # with one event apart from an arm with none.
  def hazard_value(rate)
    return "—" if rate.nil?

    number_with_precision(rate, precision: 3, significant: true, strip_insignificant_zeros: true)
  end

  def hazard_interval(interval)
    return "" if interval.value.nil?

    "(#{hazard_value(interval.lower)}–#{hazard_value(interval.upper)})"
  end

  # One epoch, or a range of them (a quartile pair) collapsed when both ends coincide.
  def epoch_value(*epochs)
    return "—" if epochs.any?(&:nil?)

    epochs.map { |epoch| number_with_delimiter(epoch.round) }.uniq.join("–")
  end
end
