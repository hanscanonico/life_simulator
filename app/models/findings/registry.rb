# frozen_string_literal: true

module Findings
  # The published findings, as data. Adding one means adding an entry here and the ERB
  # body it names; nothing else in the app knows a finding by name. Within a single date
  # ALL reads strongest-result-first, which is the order the index shows.
  module Registry
    ALL = [
      Finding.new(
        slug: "complexity-under-contest",
        title: "Does complexity keep rising when energy is contested?",
        date: Date.new(2026, 9, 18),
        experiment_slug: "host-parasite",
        related_finding_slugs: %w[complexity-keeps-rising replicator-complexity-plateau],
        status: :open,
        summary: "Complexity rises at emergence and then stops rising on every substrate " \
                 "the programme has tested, because a byte off the copy path costs its " \
                 "tape nothing and no quantity in the world is worth taking. DESIGN §1.3 " \
                 "sweep 9 prices that: instruction energy becomes a stock that carries " \
                 "across epochs, bounded by a cap, and with the steal op on a tape can " \
                 "take what a neighbour saved. The reading is pre-registered on " \
                 "dominant_instruction_count and the conserved core, never on compressed " \
                 "length, and it is taken on the last decile of a run's post-crossing " \
                 "samples against its first. No arm has read yet: this page states the " \
                 "question, the arms and the rule the claim will be made by."
      ),
      Finding.new(
        slug: "complexity-under-asymmetry",
        title: "Does complexity keep rising when only one partner's code runs?",
        date: Date.new(2026, 9, 18),
        experiment_slug: "asymmetric-execution",
        related_finding_slugs: %w[complexity-under-contest complexity-keeps-rising
                                  replicator-complexity-plateau],
        status: :open,
        summary: "Complexity rises at emergence and then stops rising on every substrate " \
                 "the programme has tested, and each bet so far changed what a tape can " \
                 "hold or spend rather than what it is to its partner. DESIGN §1.3 " \
                 "sweep 10 changes that: under a host interaction only the first tape's " \
                 "code runs, so the second is read/write substrate whose fate depends on " \
                 "how the tapes hosting it treat it as data. The reading is the " \
                 "pre-registered one of sweep 9 — dominant_instruction_count and the " \
                 "conserved core over a run's last decile against its first, never " \
                 "compressed length — with late-run distinct_lineages against the concat " \
                 "control at the same cap as the arms-race secondary. No arm has read " \
                 "yet: this page states the question, the arms and the rule the claim " \
                 "will be made by."
      ),
      Finding.new(
        slug: "complexity-keeps-rising",
        title: "Does complexity keep rising?",
        date: Date.new(2026, 9, 14),
        experiment_slug: nil,
        related_experiment_slugs: %w[energy-per-epoch environmental-structure max-tape-len],
        related_finding_slugs: %w[replicator-complexity-plateau],
        status: :open,
        summary: "The open-endedness verdict across the three substrate bets of DESIGN " \
                 "§1.3 — instruction cost, environmental structure and room to grow — " \
                 "read against the default substrate the complexity-plateau finding " \
                 "established. Each of those sweeps carries its own control arm: the cost " \
                 "off, a uniform world, a tape that cannot lengthen, the substrate every " \
                 "earlier sweep ran. This reads each sweep at render time and asks the " \
                 "same two questions of every arm — does the dominant replicator reach a " \
                 "higher complexity than the control arm reaches, and does the world keep " \
                 "more lineages alive — by placing each transitioned run above or below " \
                 "its own control and counting, never fitting a trend. An arm with too " \
                 "few transitioned seeds decides nothing, and the hypothesis it belongs " \
                 "to reads unresolved rather than answered."
      ),
      Finding.new(
        slug: "copy-cost-adaptation",
        title: "Does copying get cheaper?",
        date: Date.new(2026, 9, 13),
        experiment_slug: nil,
        status: :partial,
        summary: "Every sample now records the copy cost of the dominant replicator — the " \
                 "interpreter steps the most populous tape that passes the replicator test " \
                 "needs for one byte-exact copy — so a world that got better at copying " \
                 "itself can be seen getting better rather than inferred. This reads that " \
                 "series off every transitioned run the lab has, whichever sweep it came " \
                 "from, and counts how many end cheaper than they started. It is the first " \
                 "direct test of adaptation in the programme and it is not yet the " \
                 "adaptation sweep: the runs were assembled by having transitioned, not " \
                 "designed to answer this, and a falling cost can be a cheaper replicator " \
                 "winning rather than one lineage improving."
      ),
      Finding.new(
        slug: "replicator-complexity-plateau",
        title: "Does the replicator keep getting more complicated?",
        date: Date.new(2026, 9, 13),
        experiment_slug: nil,
        status: :partial,
        summary: "Every sample now records how much tape the dominant replicator is — the " \
                 "compressed length of the most populous tape that passes the replicator " \
                 "test, and how many of its bytes the run's instruction set executes. That " \
                 "is the open-endedness baseline every later substrate is measured " \
                 "against: a world that keeps elaborating what it found reads a rising " \
                 "length, a world that found one recipe and stopped reads a flat one. This " \
                 "reads the series off every transitioned run the lab has and counts how " \
                 "many end more complicated than they started. It measures a tape's size, " \
                 "not its abilities, and the runs were assembled by having transitioned " \
                 "rather than designed to answer this."
      ),
      Finding.new(
        slug: "emergence-can-be-left",
        title: "Emergence is a state a world can leave",
        date: Date.new(2026, 9, 12),
        experiment_slug: nil,
        status: :partial,
        summary: "DESIGN §1.2 fixes when a world enters the transitioned state, and the " \
                 "engine reports only that first crossing; nothing said when a world " \
                 "leaves one. Every terminal run now carries a persistence summary read " \
                 "off its own stored samples, and this reads every one of them the lab " \
                 "has, whichever sweep it came from: how many transitioned worlds were " \
                 "still in the state at their last sample, how many climbed back out, how " \
                 "long each held, and how high its replicator census rose. Relapse is not " \
                 "an edge case — the design record's two recorded relapses are only the " \
                 "ones that were noticed — and the outcome is split by whether the census " \
                 "ever saw a colony, since a world can leave a state no replicator was " \
                 "ever counted in. Every number is read from the database at render time " \
                 "and describes the runs the lab happens to have: each was censored by " \
                 "its own budget, so a world that persisted persisted to its last sample " \
                 "and no further."
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
    # A finding that weighs several sweeps against each other is listed by each of them.
    def self.for_experiment(experiment_slug)
      all.select { |finding| finding.rests_on?(experiment_slug) }
    end
  end
end
