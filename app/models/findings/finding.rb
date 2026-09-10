# frozen_string_literal: true

module Findings
  # One published claim: a sweep written up against its own runs (DESIGN.md §1.3). A
  # finding is content in the repo, not a database row, so it is versioned with the
  # narrative it introduces and never drifts from the data it points at.
  class Finding < Data.define(:slug, :title, :date, :experiment_slug, :status, :summary, :body_partial)
    STATUSES = %i[open confirmed refuted].freeze

    BADGE_CLASSES = { open: "badge-info", confirmed: "badge-success", refuted: "badge-error" }.freeze

    # ERB partial names must be valid Ruby identifiers, so a slug's hyphens become
    # underscores on the way to the file name.
    def initialize(slug:, title:, date:, experiment_slug:, status:, summary:, body_partial: nil)
      raise ArgumentError, "unknown finding status #{status.inspect}" unless STATUSES.include?(status)

      super(slug: slug, title: title, date: date, experiment_slug: experiment_slug, status: status,
            summary: summary, body_partial: body_partial || "findings/bodies/#{slug.tr('-', '_')}")
    end

    def to_param = slug

    def badge_class = BADGE_CLASSES.fetch(status)

    def status_label = status.to_s
  end
end
