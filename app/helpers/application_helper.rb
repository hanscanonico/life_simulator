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

  # Colour is a redundant cue on a badge that already spells the status out, so an
  # unmapped value simply stays neutral rather than raising.
  STATUS_BADGE_CLASSES = {
    "finished" => "badge-success",
    "running" => "badge-info",
    "claimed" => "badge-info",
    "failed" => "badge-error"
  }.freeze

  def status_badge_class(status) = STATUS_BADGE_CLASSES.fetch(status.to_s, "")

  # A paginated or filtered list is the same document as its bare address, so the head
  # points every variant back at the query-free URL.
  def canonical_url = request.original_url.split("?").first

  # The icon is a public/ file, not a pipeline asset, so image_url would raise
  # Propshaft::MissingAssetError rather than resolve it.
  def og_image_url = URI.join(root_url, "icon.png").to_s

  def param_value(value)
    return "—" if value.nil?

    value.is_a?(Numeric) ? Charts.format_value(value.to_f) : value.to_s
  end

  # One sampled observable. Three significant figures keep a copy rate that barely left
  # zero apart from a true zero.
  def metric_value(value)
    return "—" if value.nil?

    number_with_precision(value, precision: 3, significant: true, strip_insignificant_zeros: true)
  end

  # A hazard, already scaled to its reporting unit, reads at the same precision.
  def hazard_value(rate) = metric_value(rate)

  # A census count, integral even though jsonb hands it back as a float.
  def count_value(count)
    return "—" if count.nil?

    number_with_delimiter(count.round)
  end

  # A share of runs, read as a whole percent: fractions of a percent say more about the
  # arm's size than about the substrate.
  def percent_value(fraction)
    return "—" if fraction.nil?

    number_to_percentage(fraction * 100, precision: 0)
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
