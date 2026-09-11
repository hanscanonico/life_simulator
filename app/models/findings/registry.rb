# frozen_string_literal: true

module Findings
  # The published findings, as data. Adding one means adding an entry here and the ERB
  # body it names; nothing else in the app knows a finding by name. Within a single date
  # ALL reads strongest-result-first, which is the order the index shows.
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
        status: :partial,
        summary: "The positive control the design record makes mandatory: a well-mixed " \
                 "soup of 2^17 tapes, the shape the published BFF work used. It shows the " \
                 "transition in tape statistics in every mutated seed and the largest " \
                 "replicator census in the lab in one of them, so the interpreter and the " \
                 "pairing rule are not what the sweeps were measuring. But no stored " \
                 "world brackets that census peak at this experiment's snapshot cadence, " \
                 "and a stored world after it reads zero replicators at the locked " \
                 "16-tape ranking width against dozens at 64: in a world this size a " \
                 "lineage spreads over more tapes than the cut sees, so the census here " \
                 "is not yet resolved. Zero-mutation controls collapse entropy with a " \
                 "census of zero at every width: compression alone is not a replicator."
      ),
      Finding.new(
        slug: "world-size-scaling",
        title: "Does time to emergence scale with the number of cells?",
        date: Date.new(2026, 9, 11),
        experiment_slug: "world-size",
        status: :partial,
        summary: "DESIGN §1.3 sweep 2 sets two readings against each other: if emergence " \
                 "is a lottery, a world with more cells buys more tickets; if it is a " \
                 "per-cell rate, the epoch of the first replicator hardly moves with cell " \
                 "count. Square worlds from 32² to 256² separate them, and all but two " \
                 "runs are terminal: replicators appear only in the largest world, three " \
                 "seeds of ten of it on both observables, none anywhere below, and the " \
                 "seeds that did not move show no structure at all rather than a slow " \
                 "start. That is the lottery reading — except that the mutation-rate " \
                 "sweep transitioned in two seeds at 128² at half this mutation rate, " \
                 "where all ten seeds here found none."
      ),
      Finding.new(
        slug: "radius-locality",
        title: "Does spatial locality buy emergence?",
        date: Date.new(2026, 9, 11),
        experiment_slug: "radius",
        status: :negative,
        summary: "All 40 runs finished and 6 transitioned, but locality is not what " \
                 "decided it: the well-mixed arm transitioned as often as the best local " \
                 "arm, 2 of 10, and the tightest arm did worst. The speed half of DESIGN " \
                 "§1.3 sweep 3 is not supported — though 1 or 2 events per arm can only " \
                 "rule out an enormous effect. What the sweep does show is about the soup " \
                 "rather than emergence: among runs that never transitioned the final " \
                 "compress_ratio falls monotonically as a cell's reach widens, 0.951 to " \
                 "0.859. The diversity half of the hypothesis is untested and stays open."
      )
    ].freeze

    # Newest first: a finding list is read as a log. Findings sharing a date keep the
    # order of ALL, which leads with the strongest current result, so the index does not
    # reshuffle itself between boots.
    def self.all = ALL.sort_by.with_index { |finding, index| [-finding.date.jd, index] }.freeze

    def self.find(slug) = ALL.find { |finding| finding.slug == slug }
  end
end
