# frozen_string_literal: true

module Findings
  # The published findings, as data. Adding one means adding an entry here and the ERB
  # body it names; nothing else in the app knows a finding by name. Within a single date
  # ALL reads strongest-result-first, which is the order the index shows.
  module Registry
    ALL = [
      Finding.new(
        slug: "emergence-can-be-left",
        title: "Emergence is a state a world can leave",
        date: Date.new(2026, 9, 12),
        experiment_slug: nil,
        status: :partial,
        summary: "DESIGN §1.2 fixes when a world enters the transitioned state, and the " \
                 "engine reports only that first crossing; nothing said when a world " \
                 "leaves one. Every terminal run now carries a persistence summary read " \
                 "off its own stored samples, and this is every one of them the lab has, " \
                 "whichever sweep it came from: how many transitioned worlds were still " \
                 "in the state at their last sample, how many climbed back out, how long " \
                 "each held, and how high its replicator census rose. Relapse is not an " \
                 "edge case: mutation-rate-long's 2^-12 seed 10 climbed back out after a " \
                 "census peak of 123, and so did the radius sweep's radius-2 run, whose " \
                 "census never counted a cell at all — which is why the counts are split " \
                 "by whether the census ever saw a colony. The counts are read from the " \
                 "database at render time and describe the runs the lab happens to have: " \
                 "each was censored by its own budget, so a world that persisted " \
                 "persisted to its last sample and no further."
      ),
      Finding.new(
        slug: "mutation-rate-long-horizon",
        title: "Emergence is rare, and half of it happens after epoch 20 000",
        date: Date.new(2026, 9, 11),
        experiment_slug: "mutation-rate-long",
        status: :partial,
        summary: "The four rates around sweep 1's transitions, re-run for 60 000 epochs — " \
                 "three times the budget that produced the mutation-rate window finding. " \
                 "It reproduces that sweep run for run and then doubles it: six of 40 runs " \
                 "reach a census-confirmed replicator, and half of those transitions land " \
                 "after epoch 20 000, where the short sweep had already stopped watching. " \
                 "One of its disagreements resolves the same way — the run it recorded as " \
                 "flagged with an empty census counts replicators at epoch 26 140. The " \
                 "2^-14 arm stays silent at three times the budget, so the lower cutoff " \
                 "is not a censoring artefact."
      ),
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
                 "transition in tape statistics in one mutated seed and the largest " \
                 "replicator census in the lab in another, so the interpreter and the " \
                 "pairing rule are not what the sweeps were measuring. But no stored " \
                 "world brackets that census peak at this experiment's snapshot cadence, " \
                 "so the count cannot yet be rescored and the census here is not yet " \
                 "resolved. A zero-mutation control collapses entropy with a census of " \
                 "zero: compression alone is not a replicator."
      ),
      Finding.new(
        slug: "world-size-scaling",
        title: "Does time to emergence scale with the number of cells?",
        date: Date.new(2026, 9, 11),
        experiment_slug: "world-size",
        status: :partial,
        summary: "DESIGN §1.3 sweep 2 sets two readings against each other: if emergence " \
                 "is a hazard per cell-epoch, a world with more cells buys more tickets " \
                 "and events scale with cell count; if it is a hazard per world, cell " \
                 "count buys nothing. Square worlds from 32² to 256² separate them, and " \
                 "emergence gets more likely as the world gets bigger: 0, 0, 1 and 3 of " \
                 "10 seeds transitioned, against the 0.06, 0.26, 1 and 3.7 a constant " \
                 "per-cell hazard predicts. Pooled, that hazard is 2.5 × 10⁻¹⁰ per " \
                 "cell-epoch (95% 0.7–6.4). The earliest transition of the whole " \
                 "programme, epoch 4 730, is a 256² run — but four events cannot measure " \
                 "an exponent, and two of them are still resuming from their snapshots."
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
      ),
      Finding.new(
        slug: "interaction-budget",
        title: "More compute per interaction is not more life",
        date: Date.new(2026, 9, 11),
        experiment_slug: "max-steps",
        status: :partial,
        summary: "DESIGN §1.3 sweep 4 expected a floor: below some number of instructions " \
                 "a copy cannot finish, above it the budget should stop mattering. What " \
                 "the four arms show instead is a single positive point. In 20 000 epochs " \
                 "at 128×128 emergence appears only at max_steps 8 192, 2 of 10 seeds, and " \
                 "never at 256, 1 024 or 65 536 — the arm with eight times the compute of " \
                 "the one that works produces nothing, and the extra instructions are spent " \
                 "rather than merely bought: an epoch at 65 536 costs twelve times an epoch " \
                 "at 256. The detector and the census agree in every arm, which is rare in " \
                 "this programme. But a peak found by one arm out of four is located to " \
                 "within a factor of 64, and each silent arm bounds its rate only to " \
                 "about 0–26%."
      )
    ].freeze

    # Newest first: a finding list is read as a log. Findings sharing a date keep the
    # order of ALL, which leads with the strongest current result, so the index does not
    # reshuffle itself between boots.
    def self.all = ALL.sort_by.with_index { |finding, index| [-finding.date.jd, index] }.freeze

    def self.find(slug) = ALL.find { |finding| finding.slug == slug }

    # The write-ups resting on one sweep, newest first: a finding is content in the repo,
    # not a row, so every page that links up to one reads it from here rather than querying.
    def self.for_experiment(experiment_slug)
      all.select { |finding| finding.experiment_slug == experiment_slug }
    end
  end
end
