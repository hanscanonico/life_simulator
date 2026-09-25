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
        "The arm-by-arm reading of whether complexity keeps rising is exposed. " \
        "dominant_instruction_count is read off the commonest tape that passes the " \
        "same-orientation replicator test where one does and off the commonest tape of the " \
        "world where none does, so a run's series can switch between two different tapes, " \
        "and the conserved core compares aligned bytes, which a population of reverse " \
        "copiers and their reverses confounds. Which runs emerged stands for now: read with " \
        "the orientation-aware detector, every one of the 1 290 finished runs of this sweep " \
        "that did not emerge shows a replicator_share of 0 in its last stored world, and 24 " \
        "of the 27 that did show 0.5 or more. Whether theft evolved does not rest on the census.",
      "complexity-under-asymmetry" =>
        "That nothing emerged under the host interaction does not rest on the census: the " \
        "detector never flagged a host run. The concat controls' reference readings are " \
        "exposed: dominant_instruction_count is read off the commonest tape that passes the " \
        "same-orientation replicator test where one does and off the commonest tape of the " \
        "world where none does, the conserved core and distinct_lineages compare aligned " \
        "bytes, and a pilot found these same worlds, run as sweep 9's control, to be mostly " \
        "replicators that copy themselves in reverse.",
      "complexity-keeps-rising" =>
        "Every verdict on this page is exposed. dominant_instruction_count is read off the " \
        "commonest tape that passes the same-orientation replicator test where one does and " \
        "off the commonest tape of the world where none does, so a run's series can switch " \
        "between two different tapes, and distinct_lineages follows descent by comparing " \
        "aligned bytes, which a population of reverse copiers and their reverses confounds. " \
        "How often each arm emerged stands for now, though an orientation-aware check has " \
        "supported the emergence gate on sweep 9 only; the comparison of the two detector " \
        "rules rests on compress_ratio and is unaffected.",
      "copy-cost-adaptation" =>
        "Every copy cost on this page is exposed. It is priced on the commonest of the " \
        "sixteen tested tapes that passes the same-orientation replicator test, so it can " \
        "only price a palindrome or a forward copier, and the replicators that dominate " \
        "emerged worlds copy themselves in reverse. Which runs transitioned is the " \
        "detector's and does not rest on the census; what their cost series say is under " \
        "re-read.",
      "replicator-complexity-plateau" =>
        "The lengths and instruction counts on this page are exposed. They are read off the " \
        "commonest of the sixteen tested tapes that passes the same-orientation replicator " \
        "test, which in an emerged world can be a rare palindrome rather than the reverse " \
        "copier holding most of its cells, and, on samples recorded since September 15, " \
        "off the commonest tape of the world where none passes, so a run's series can " \
        "switch between two different tapes. Which runs count as emerged stands for now, " \
        "though an orientation-aware check has supported the emergence gate on sweep 9 only.",
      "emergence-can-be-left" =>
        "This page is the most exposed on the site. Its census split, its census peaks and " \
        "its reading that a relapse with a zero census is a soup that stopped compressing " \
        "rather than a colony that died all rest on a census that reads reverse copiers as " \
        "nothing: a pilot found worlds whose census never left zero holding working " \
        "replicators, and emerged worlds at a census of zero to be 74–99% replicators, " \
        "copying 20 to 45 times faster than mutation undoes them. Entering and leaving the " \
        "state are read off compress_ratio, but the pilot read no world that had left it, " \
        "so whether a relapse is a colony dying, a colony the compression rule no longer " \
        "sees, or no colony at all is under re-read.",
      "mutation-rate-long-horizon" =>
        "Which runs the detector flagged, and when, rests on compress_ratio and stands. " \
        "Exposed: the census peaks and the two runs read as flagged with an empty census, " \
        "and with them the lower cutoff, since the lowest arm's one flagged run is one of " \
        "the two; the census cannot count replicators that copy in reverse, and whether " \
        "the confirmed lineage that fell back to a soup's compress_ratio left no replicator " \
        "behind is under re-read. The six census-confirmed runs stand for now, a census " \
        "positive being a tape that copies itself, though an orientation-aware check has " \
        "supported the emergence gate on sweep 9 only.",
      "mutation-rate-window" =>
        "The transition counts per arm, the missing window and the Fisher test rest on the " \
        "detector and stand, and the ordering of the soup floor rests on compress_ratio " \
        "alone and is unaffected. Exposed: the reading that the census fades after its peak " \
        "because the lineage is gone, and the runs read as flagged with an empty census. " \
        "The census cannot count replicators that copy in reverse, and the census " \
        "positives on record are palindromes.",
      "bff-control" =>
        "Exposed: the census readings as a count of replicators, and this page's reasoning " \
        "that with no mutation nothing that replicates can emerge. A pilot read three of " \
        "this control's last stored worlds, each at a census of zero, and found working " \
        "reverse copiers in 78% and 97% of the cells of two mutated worlds, and in 25% of " \
        "a zero-mutation world whose compress_ratio had collapsed too. That world is not " \
        "the one this page describes, which fell to two byte values, was not in the pilot " \
        "and is under re-read; the transition signature in the tape statistics does not " \
        "rest on the census and stands.",
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
