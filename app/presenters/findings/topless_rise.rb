# frozen_string_literal: true

module Findings
  # The topless-rise sweep's pre-registered reading (DESIGN §1.3 item 18) as the finding that
  # states it. `report` is the sweep's Lab::ToplessRiseReading::Report: every verdict, count, p
  # and carrying parent is its own, and this only sums what the finding says about it — each
  # test beside its two re-readings, and which children of each arm rose late.
  class ToplessRise
    RISE = "H-rise"
    RISE_PAID = "H-rise-paid"

    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :any?, :interim?, :arms, :tests, :readings, :mostly_ceilinged?, to: :report

    def test(hypothesis) = tests.find { |test| test.hypothesis == hypothesis }

    def rise = test(RISE)

    def rise_paid = test(RISE_PAID)

    def shown?(test) = test.outcome == :held

    # The pre-registration's "the climb stops": H-rise refuted or not shown.
    def climb_stopped? = !shown?(rise)

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    # An arm's children that rose late, in (parent, seed) order.
    def late_risers(key) = arm(key).children.select(&:rises?).sort_by { |child| [child.parent_id, child.seed] }

    def relapse_count(key) = arm(key).children.count(&:settled_relapse?)

    def extinct_count = arms.sum { |candidate| candidate.children.count(&:extinct?) }

    def ceilinged_count = report.ceilinged.size
  end
end
