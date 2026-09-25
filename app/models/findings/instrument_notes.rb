# frozen_string_literal: true

module Findings
  # What the census blind spot (design record 2026-09-25, GitHub #245) does to each published
  # finding, kept apart from the findings themselves: a note says which of a page's claims
  # rest on an instrument now known to miss the replicators that copy in reverse, and which
  # do not, without touching a claim. A finding with no exposed claim has no entry. The map
  # goes away finding by finding as each is re-read with the orientation-aware detector.
  module InstrumentNotes
    ISSUE_URL = "https://github.com/hanscanonico/life_simulator/issues/245"

    DATE = Date.new(2026, 9, 25)

    NOTES = {
      "complexity-under-contest" =>
        "The arm-by-arm reading of whether complexity keeps rising is exposed: " \
        "dominant_instruction_count is read off the commonest tape that passes the " \
        "same-orientation replicator test, and the conserved core compares aligned bytes, so " \
        "neither sees the reverse copiers that dominate these worlds. Which runs emerged " \
        "stands for now: read with the orientation-aware detector, all 1 290 finished runs " \
        "of this sweep that did not emerge hold no replicator in their last stored world, " \
        "and in 24 of the 27 that did, at least half of its sampled cells replicate. Whether " \
        "theft evolved does not depend on the census.",
      "complexity-under-asymmetry" =>
        "That nothing emerged under the host interaction rests on the emergence gate, which " \
        "an orientation-aware check supports on sweep 9 only and has not yet re-read here. " \
        "The concat controls' reference readings — dominant_instruction_count, the " \
        "conserved core and the distinct_lineages secondary — are exposed: they read the " \
        "commonest same-orientation replicator or compare aligned bytes, and the " \
        "replicators of these worlds copy themselves in reverse.",
      "complexity-keeps-rising" =>
        "The three verdicts are exposed: they are read off dominant_instruction_count, " \
        "taken from the commonest tape that passes the same-orientation replicator test, " \
        "and off distinct_lineages, which follows descent by comparing aligned bytes, and " \
        "neither sees the reverse copiers that dominate emerged worlds. How often each arm " \
        "emerged stands for now, though an orientation-aware check supports the emergence " \
        "gate on sweep 9 only. The comparison of the two detector rules rests on " \
        "compress_ratio alone and is unaffected.",
      "copy-cost-adaptation" =>
        "Every copy cost on this page is exposed. It is priced on the commonest of the " \
        "sixteen tested tapes that passes the same-orientation replicator test, so it can " \
        "only price a palindrome or a forward copier, and the replicators that dominate " \
        "emerged worlds copy themselves in reverse. Which runs transitioned is the " \
        "detector's and is not in question; what their cost series say is under re-read.",
      "replicator-complexity-plateau" =>
        "The lengths and instruction counts on this page are exposed: they are read off the " \
        "commonest of the sixteen tested tapes that passes the same-orientation replicator " \
        "test, which in an emerged world can be a rare palindrome rather than the reverse " \
        "copier holding most of its cells. Which runs count as emerged stands for now, " \
        "though an orientation-aware check supports the emergence gate on sweep 9 only.",
      "emergence-can-be-left" =>
        "This page is the most exposed on the site. Its census split, its census peaks and " \
        "its reading that a relapse with a zero census held no colony all rest on a census " \
        "that reads reverse copiers as nothing, and a pilot found emerged worlds the census " \
        "read as empty to be 74–99% working replicators, copying 20 to 45 times faster than " \
        "mutation undoes them. Entry into the state and exit from it are read off " \
        "compress_ratio, but what a relapse means — a colony that died, or one the census " \
        "never saw — is under re-read.",
      "mutation-rate-long-horizon" =>
        "Which runs the detector flagged, and when, rests on compress_ratio and stands. The " \
        "census readings are exposed: the peak counts, the runs read as flagged with an " \
        "empty census, and the reading that a confirmed lineage dissolved all rest on a " \
        "census that cannot count replicators copying in reverse. Census-confirmed " \
        "emergence stands for now, though an orientation-aware check supports it on " \
        "sweep 9 only.",
      "mutation-rate-window" =>
        "The transition counts per arm, the missing window and the Fisher test rest on the " \
        "detector and stand, and the ordering of the soup floor rests on compress_ratio " \
        "alone and is unaffected. Exposed: the reading that the census fades after its peak " \
        "because the lineage is gone, and the runs read as flagged with an empty census. " \
        "The census cannot count replicators that copy in reverse, and the census " \
        "positives on record are palindromes.",
      "bff-control" =>
        "Exposed: the census readings, and with them the reading that the zero-mutation " \
        "control's collapse held no replicator. A pilot read stored worlds of this control " \
        "as working reverse copiers at a census of zero — 78% and 97% of the cells of two " \
        "mutated worlds, 25% of a zero-mutation one. The transition signature in the tape " \
        "statistics rests on compress_ratio and stands; the rescored census counts are " \
        "under re-read as a measure of how many replicators those worlds held.",
      "world-size-scaling" =>
        "The detector counts and the per-cell hazard fitted to them rest on compress_ratio " \
        "and stand, as does the reading of the pre-emergence soup. Exposed: the census " \
        "counts per arm, and the reading that the 128² arm's flagged run, which lifted " \
        "copy_rate with a census of zero, is a collapse and not a replicator — the census " \
        "cannot count replicators that copy in reverse.",
      "interaction-budget" =>
        "The transition counts per arm and the cost of an epoch stand: they rest on the " \
        "detector and on timings, not on the census. Exposed: the census peaks, and the " \
        "reading that the detector and the census agree in every arm — the census counts " \
        "only replicators that copy in their own orientation, so an agreement says it saw " \
        "a replicator, not that it saw them all."
    }.freeze

    def self.for(slug) = NOTES[slug]
  end
end
