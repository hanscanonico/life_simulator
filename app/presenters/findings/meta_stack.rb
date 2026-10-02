# frozen_string_literal: true

module Findings
  # The meta-stack sweep's pre-registered reading (DESIGN §1.3 item 17) as the finding that
  # states it. `report` is the sweep's Lab::MetaStackReading::Report: every verdict, count, p
  # and carrying parent is its own, and this only sums what the finding says about it — how
  # the parents lean, which re-reading one or two parents carry, and which children reached a
  # deep rung.
  class MetaStack
    DEEP = "H-deep-Ms"
    STONES = "H-stones-Ms"
    STACK = "H-stack"
    DEEP_IN_PLACE = "H-deep-M"
    DECOUPLE = "H-decouple"
    CAPABILITY = "H-capability-M"

    # How one test's parents lean: more pairs favouring the treated arm, all measured pairs
    # tied, or more pairs favouring the control. A parent whose favouring and against pairs
    # balance off a tie leans neither way and is counted in none.
    Leaning = Data.define(:treated, :tied, :control)

    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :any?, :interim?, :arms, :tests, to: :report

    def test(hypothesis) = tests.find { |test| test.hypothesis == hypothesis }

    def kept(hypothesis) = sensitivity(report.kept_tests, hypothesis, Lab::MetaStackReading::KEPT_SUFFIX)

    def unpiloted(hypothesis)
      sensitivity(report.unpiloted_tests, hypothesis, Lab::MetaStackReading::UNPILOTED_SUFFIX)
    end

    def deep = test(DEEP)

    def stones = test(STONES)

    def stack = test(STACK)

    def capability = test(CAPABILITY)

    def shown?(test) = test.outcome == :held

    # The pre-registration's "assembled from paid parts": H-deep-Ms shown with H-stones-Ms.
    def assembled? = shown?(deep) && shown?(stones)

    def leaning(test)
      rows = test.comparison.agreement.select { |row| (row.treatment + row.continuation + row.ties).positive? }
      Leaning.new(treated: rows.count { |row| row.treatment > row.continuation },
                  tied: rows.count { |row| row.treatment.zero? && row.continuation.zero? },
                  control: rows.count { |row| row.continuation > row.treatment })
    end

    def parent_count = report.children.map(&:parent_id).uniq.size

    # Whether every parent's measured pairs all favour the treated arm.
    def unanimous?(test) = test.comparison.agreement.all? { |row| row.continuation.zero? && row.ties.zero? }

    def shown_tests = tests.select { |test| shown?(test) }

    # The shown tests that one or two parents carry, by the leave-out rule.
    def carried_tests = tests.select { |test| test.comparison.carried_by.any? }

    # The re-readings, extinct pairs kept or piloted parents left out, that one or two
    # parents carry. They decide no outcome, but the page states each.
    def carried_sensitivities
      [*report.kept_tests, *report.unpiloted_tests].select { |test| test.comparison.carried_by.any? }
    end

    def stack_arm = arm(:meta_stack)

    # The meta-stack children whose worlds held XOR or EQU at a tenth, in (parent, seed) order.
    def deep_children = stack_arm.children.select(&:climbed_deep?).sort_by { |child| [child.parent_id, child.seed] }

    def deep_parent_count = deep_children.map(&:parent_id).uniq.size

    def deep_count(arm) = arm.children.count(&:climbed_deep?)

    def extinct_count(arm) = arm.children.count(&:extinct?)

    private

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    def sensitivity(readings, hypothesis, suffix) = readings.find { |test| test.hypothesis == "#{hypothesis}#{suffix}" }
  end
end
