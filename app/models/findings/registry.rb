# frozen_string_literal: true

module Findings
  # The published findings, as data. Adding one means adding an entry here and the ERB
  # body it names; nothing else in the app knows a finding by name.
  module Registry
    ALL = [
      Finding.new(
        slug: "mutation-rate-window",
        title: "Does a mutation-rate window exist for spontaneous replicators?",
        date: Date.new(2026, 9, 10),
        experiment_slug: "mutation-rate",
        status: :open,
        summary: "DESIGN §1.3 sweep 1 holds that there is a window: with no mutation at all " \
                 "emergence is delayed, and above an error threshold — Eigen's quasispecies " \
                 "bound — mutation destroys any replicator faster than it can copy itself. " \
                 "The sweep is running; this finding stays open until every run has finished."
      ),
      Finding.new(
        slug: "bff-control",
        title: "Does the engine reproduce BFF emergence at all?",
        date: Date.new(2026, 9, 11),
        experiment_slug: "bff-control",
        status: :open,
        summary: "The positive control the design record makes mandatory: a well-mixed " \
                 "soup of 2^17 tapes, the shape the published BFF work used. Until this " \
                 "one transitions, no sweep of ours is readable as a negative result — a " \
                 "flat sweep would only say the instrument is untested."
      )
    ].freeze

    # Newest first: a finding list is read as a log.
    def self.all = ALL.sort_by(&:date).reverse

    def self.find(slug) = ALL.find { |finding| finding.slug == slug }
  end
end
