# frozen_string_literal: true

module Findings
  # The published findings, as data. Adding one means adding an entry here and the ERB
  # body it names; nothing else in the app knows a finding by name. Within a single date
  # ALL reads strongest-result-first, which is the order the index shows.
  module Registry
    ALL = [
      Finding.new(
        slug: "reach-4-carries-to-growable-tapes",
        title: "On growable tapes, a reach of 4 emerges more than ten times as often as radius 1",
        date: Date.new(2026, 10, 3),
        experiment_slug: "reach-cap128",
        related_finding_slugs: %w[emergence-peaks-at-intermediate-reach],
        status: :published,
        summary: "DESIGN §1.3 sweep 14 asked whether the best reach of the locality finding " \
                 "carries to the growable tapes every rung-4 experiment runs on: the host–parasite " \
                 "sweep's economy-off world at cap 128, tapes of 64 bytes free to grow to 128, at " \
                 "radius 4 on that control's seeds 1–270. All 270 runs finished and every world " \
                 "they kept was read. Radius 4 emerged in 119 of 270 worlds against the control's " \
                 "11 of 270 at radius 1, 10.8 times the rate (one-sided Fisher p = 1.5e-30), so " \
                 "the pre-registered test is shown. On fixed 64-byte tapes sweep 13 had read " \
                 "radius 4 at four times radius 1. In both arms the dominant replicator fills " \
                 "the 128 bytes it may grow to. 108 of the emerged worlds at radius 4 end with " \
                 "replicators holding at least half the world, against 11 in the control: a pool " \
                 "of parents with room to grow, though no later sweep's rule is set by it."
      ),
      Finding.new(
        slug: "paid-parts-assemble-deep-logic-on-a-stack-nand",
        title: "With a stack NAND on a metabolism tape, paid parts assemble the logic rungs that need " \
               "an input twice, in a sixth of the worlds",
        date: Date.new(2026, 10, 2),
        experiment_slug: "meta-stack",
        related_finding_slugs: %w[paid-logic-climbs-only-read-once-tasks paid-computation-stops-at-one-step-tasks],
        status: :published,
        imports_objective: true,
        summary: "DESIGN §1.3 sweep 17 moved the Logic sweep's computing off the copier: a second, " \
                 "32-byte tape the soup never runs, handed on with each copy and read by the assay " \
                 "with a NAND that keeps its operands. The 18 emerged worlds ran another 40 000 " \
                 "epochs, three seeds a parent, paired with the Logic sweep's children. All 162 " \
                 "children finished and none died out. 9 children of 54, from 7 parents, held XOR " \
                 "or EQU at a tenth of their world, against none in any other arm, so the rung-4 " \
                 "question is shown, 9 pairs to 0 with 45 ties (p = 0.00195). The stepping-stone " \
                 "test against the arm paid for XOR and EQU alone is shown too, 9 to 0: the deep " \
                 "rungs were assembled from paid parts, Lenski's mechanism in a soup. The same tape " \
                 "read by the NAND that writes in place built none. Without the four piloted " \
                 "parents the deep tests read 8 to 0 and rest on two parents. In 14 of 15 plantings a " \
                 "world the deep rung was wiped from re-grew it within 500 epochs: a property of " \
                 "the population more than of a lineage. The ladder tops out at EQU, and the substrate " \
                 "imports an objective, a primitive, a hereditary channel and the semantics that " \
                 "let the deep rungs come, so rung 4 on Soup stays not shown."
      ),
      Finding.new(
        slug: "paid-computation-stops-at-one-step-tasks",
        title: "Paid to compute, replicators take the one-step tasks and stop there",
        date: Date.new(2026, 10, 2),
        experiment_slug: "metabolism",
        related_finding_slugs: %w[complexity-from-an-emerged-start copying-gets-faster-under-an-economy],
        status: :negative,
        imports_objective: true,
        summary: "DESIGN §1.3 sweep 15 paid replicators for computing. The 18 emerged worlds of " \
                 "the from-emerged sweep ran another 40 000 epochs each, three seeds a parent, " \
                 "with arithmetic tasks rewarded and, in a paired twin, assayed but unpaid. All " \
                 "108 children finished and none died out. Pay bought capability: all 54 pairs " \
                 "favour the reward (p = 5.55e-17), and the paid worlds took ECHO, INC and DEC, " \
                 "the tasks one substitution of a copier computes. They went no further. The " \
                 "rung-4 question, whether paid computation climbs to the tasks that need a " \
                 "counted loop, is refuted: no child of either arm held a loop task at a tenth " \
                 "of its world, 0 to 0 with 54 ties. Paid complexity did rise, in 18 pairs " \
                 "against 1 (p = 3.81e-05), and both shown tests hold without the piloted " \
                 "parents. The substrate imports an objective, so none of this moves rung 4 on " \
                 "Soup, which stays not shown."
      ),
      Finding.new(
        slug: "paid-logic-climbs-only-read-once-tasks",
        title: "Given a NAND, paid replicators climb every logic task that reads its inputs once, " \
               "and none that needs one twice",
        date: Date.new(2026, 10, 2),
        experiment_slug: "logic",
        related_finding_slugs: %w[paid-computation-stops-at-one-step-tasks],
        status: :negative,
        imports_objective: true,
        summary: "DESIGN §1.3 sweep 16 gave paid replicators a NAND. The 18 emerged worlds of the " \
                 "from-emerged sweep ran another 40 000 epochs each, three seeds a parent, with an " \
                 "assay-only NAND byte and Avida's logic tasks as the ladder, in three arms: every " \
                 "rung paid, XOR and EQU alone paid, and nothing paid. All 162 children finished; " \
                 "one paid child died out. Pay bought capability: all 53 measured pairs favour the " \
                 "paid ladder (p = 1.11e-16), and the paid worlds climbed every rung from NOT to " \
                 "NOR, the tasks a NAND circuit can compute reading each input once. None held XOR " \
                 "or EQU, the two that need an input twice, at a tenth of its world. The rung-4 " \
                 "question, whether a soup assembles those deep rungs from paid parts, is refuted, " \
                 "0 to 0 with 53 ties, and so is the stepping-stone test against the arm paid for " \
                 "XOR and EQU alone. Paid complexity did not rise, 2 pairs against 1 (p = 0.5). The " \
                 "substrate imports an objective and a primitive, so none of this moves rung 4 on " \
                 "Soup, which stays not shown."
      ),
      Finding.new(
        slug: "emergence-peaks-at-intermediate-reach",
        title: "Emergence peaks at an intermediate reach",
        date: Date.new(2026, 10, 1),
        experiment_slug: "locality-emergence",
        related_finding_slugs: %w[lineages-after-emergence radius-locality],
        status: :published,
        summary: "DESIGN §1.3 sweep 13 put an exploratory pattern from sweep 12 to fresh " \
                 "worlds under rules fixed first: does a replicator arise more often at an " \
                 "intermediate reach than at the tightest one or in a well-mixed world? All " \
                 "630 runs finished, 90 fresh seeds at each of seven reaches. Radius 4 " \
                 "emerged in 16 of 90 worlds, against 4 of 90 at radius 1 and 3 of 90 " \
                 "well-mixed (one-sided Fisher, Holm-corrected p = 0.0039 and 0.0027), and a " \
                 "logistic fit over the six finite radii bends down (radius² coefficient " \
                 "−0.114, Wald p = 0.0041) with its peak at radius 4.1. Both pre-registered " \
                 "hypotheses are shown. Four of the seven arms emerged exactly as often as " \
                 "sweep 12's did: different seeds and different worlds, the same totals."
      ),
      Finding.new(
        slug: "copying-gets-faster-under-an-economy",
        title: "Under an energy economy, the dominant replicator copies itself faster",
        date: Date.new(2026, 9, 28),
        experiment_slug: "from-emerged",
        related_finding_slugs: %w[copy-cost-adaptation complexity-from-an-emerged-start],
        status: :published,
        summary: "DESIGN §1.3 sweep 11 continued emerged worlds for another 20 000 epochs, " \
                 "each paired with a continuation under its own dynamics. A confirmatory " \
                 "reading, written after ten parents had been seen and tested only on the " \
                 "eight that qualified afterwards, asked rung 3's question: under an energy " \
                 "economy, does the dominant replicator get faster at copying itself? It " \
                 "does. Its copy_latency, the step at which a partner first holds a " \
                 "complete image, fell relative to the paired continuation in 20 of 24 pairs " \
                 "at economy 2048 (p = 0.00077) and 21 of 24 at economy 8192 (p = 0.00014). " \
                 "The median child's last-decile latency was 0.82 and 0.75 of its " \
                 "first-decile latency under the two economies, against 1.11 in the " \
                 "continuation, and the result holds in 7 and 8 of the 8 parents. It is the " \
                 "programme's first confirmed adaptation: one substrate, latency read on " \
                 "the dominant tape in isolation, and the mechanism is not identified."
      ),
      Finding.new(
        slug: "complexity-from-an-emerged-start",
        title: "From an emerged start, an energy economy does not keep complexity rising",
        date: Date.new(2026, 9, 28),
        experiment_slug: "from-emerged",
        related_finding_slugs: %w[complexity-under-contest copying-gets-faster-under-an-economy],
        status: :negative,
        summary: "DESIGN §1.3 sweep 11 asked whether an existing replicator keeps getting " \
                 "more complicated once a treatment is switched on: 216 continuations of 18 " \
                 "emerged worlds, 20 000 epochs each, under the parent's own dynamics, two " \
                 "energy economies or host mode. Read as pre-registered, neither economy " \
                 "arm can be read, because each relapses more than the continuation; the " \
                 "rich economy's sign test (12 pairs to 1) rests on two parents. Host mode " \
                 "is refuted, and so is strict persistence: 52 of 54 continuations held " \
                 "their replicators and 2 relapsed. A held-out confirmatory reading on the " \
                 "survivors of 8 unseen parents did not replicate the complexity signal: " \
                 "refuted at economy 2048, not shown at economy 8192 (1 pair to 0). From an " \
                 "emerged start the economy does not keep complexity rising."
      ),
      Finding.new(
        slug: "lineages-after-emergence",
        title: "After emergence, one lineage takes the world at every reach",
        date: Date.new(2026, 9, 27),
        experiment_slug: "lineage-diversity",
        related_finding_slugs: %w[radius-locality],
        status: :negative,
        summary: "DESIGN §1.3 sweep 12 asked rung 2's question: once a world has made " \
                 "replicators, does it stay polyphyletic, and do more lineages survive as a " \
                 "cell's reach shrinks? All 360 runs finished and 32 emerged. Read by the " \
                 "pre-registered rule, on lineage tags that follow descent through reverse " \
                 "copies, none of them stayed polyphyletic: 27 read monophyletic, 5 between " \
                 "one lineage and two, and the median effective number of lineages is 1 in " \
                 "every arm, well-mixed to radius 1. The trend toward more lineages at shorter " \
                 "reach is neither shown nor refuted, at a permutation p of 0.079. Emergence " \
                 "itself differed by reach — 3, 16, 9 and 4 runs of 90, well-mixed then radius " \
                 "4, 2 and 1 — which the sweep was not designed to test and is reported " \
                 "descriptively only."
      ),
      Finding.new(
        slug: "complexity-under-contest",
        title: "Does complexity keep rising when energy is contested?",
        date: Date.new(2026, 9, 18),
        experiment_slug: "host-parasite",
        related_finding_slugs: %w[complexity-keeps-rising replicator-complexity-plateau],
        status: :partial,
        summary: "Complexity rises at emergence and then stops rising on every substrate " \
                 "the programme has tested, because a byte off the copy path costs its " \
                 "tape nothing and no quantity in the world is worth taking. DESIGN §1.3 " \
                 "sweep 9 priced that — instruction energy as a stock, with a steal op " \
                 "that takes what a neighbour saved — and the sweep has finished. Pricing " \
                 "energy did not make life more common: no priced arm emerged significantly " \
                 "more often than the economy-off control at its cap, and the poorest economy held no " \
                 "replicator at all. Theft evolved wherever it was offered. Read arm by arm " \
                 "on dominant_instruction_count and the conserved core, no priced arm the " \
                 "rule reads keeps rising: the one that did at 90 seeds, on one of its two " \
                 "measured runs, reads neither at 270, beside its control at 270, and the " \
                 "rest plateau, read neither or are barren. Two arms that were never " \
                 "extended hold one measured run each, and it rises, too few for the rule " \
                 "to read, so the verdict is unresolved rather than negative. That " \
                 "reading stands on a measured-run rule amended after the data were seen; " \
                 "as registered, the rule reads almost every emerged run as unmeasured and " \
                 "no arm at all."
      ),
      Finding.new(
        slug: "complexity-under-asymmetry",
        title: "Does complexity keep rising when only one partner's code runs?",
        date: Date.new(2026, 9, 18),
        experiment_slug: "asymmetric-execution",
        related_finding_slugs: %w[complexity-under-contest complexity-keeps-rising
                                  replicator-complexity-plateau],
        status: :negative,
        summary: "Complexity rises at emergence and then stops rising on every substrate " \
                 "the programme has tested, and each bet so far changed what a tape can " \
                 "hold or spend rather than what it is to its partner. DESIGN §1.3 " \
                 "sweep 10 changed that — under a host interaction only the first tape's " \
                 "code runs — and the sweep has finished. Under it nothing emerged at all: " \
                 "the host arms are barren at both caps while the concat controls beside " \
                 "them held replicators, so the asymmetry did not lower the plateau, it " \
                 "kept replication from arising. With no host run to read, the " \
                 "pre-registered refutation and the distinct_lineages secondary cannot be " \
                 "evaluated; the concat controls, the same worlds sweep 9's control ran " \
                 "on its seeds 1–90, are read as the reference."
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
                 "pairing rule are not what the sweeps were measuring. Two of its stored " \
                 "worlds sit on census-positive samples and rescore to the live count " \
                 "exactly, 316 replicating cells and 112, so the census is real; but no " \
                 "stored world brackets the peak itself at this experiment's snapshot " \
                 "cadence, so its height is still read from in-run samples alone. A " \
                 "zero-mutation control collapses entropy with a census of " \
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
