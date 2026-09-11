# frozen_string_literal: true

module Findings
  # The published findings, as data. Adding one means adding an entry here and the ERB
  # body it names; nothing else in the app knows a finding by name.
  module Registry
    ALL = [
      Finding.new(
        slug: "mutation-rate-window",
        title: "Life emerged, but the mutation-rate window did not",
        date: Date.new(2026, 9, 11),
        experiment_slug: "mutation-rate",
        status: :partial,
        summary: "All 100 runs finished, and five of them crossed the transition: " \
                 "self-replicating structure arose from a random soup with no fitness " \
                 "function, the first at epoch 5 030. But it arose at 2^-13, 2^-12, 2^-9 " \
                 "and 2^-8 alike, about one seed in ten wherever it arose, so the window " \
                 "of DESIGN §1.3 sweep 1 is not supported at this scale. Only a lower " \
                 "cutoff is hinted at: 0 of 40 runs below 2^-13 against 5 of 60 at or " \
                 "above it, one-sided Fisher p ≈ 0.073."
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
      ),
      Finding.new(
        slug: "world-size-scaling",
        title: "Does time to emergence scale with the number of cells?",
        date: Date.new(2026, 9, 11),
        experiment_slug: "world-size",
        status: :open,
        summary: "DESIGN §1.3 sweep 2 sets two readings against each other: if emergence " \
                 "is a lottery, a world with more cells buys more tickets and transitions " \
                 "sooner; if it is a per-cell rate, the epoch of the first replicator " \
                 "hardly moves with cell count. Square worlds from 32² to 256² separate " \
                 "them. No claim yet — the sweep is running."
      )
    ].freeze

    # Newest first: a finding list is read as a log.
    def self.all = ALL.sort_by(&:date).reverse

    def self.find(slug) = ALL.find { |finding| finding.slug == slug }
  end
end
