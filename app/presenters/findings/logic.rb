# frozen_string_literal: true

module Findings
  # The logic sweep's pre-registered reading (DESIGN §1.3 item 16) as the finding that states
  # it. `report` is the sweep's Lab::LogicReading::Report: every verdict, count, p and carrying
  # parent is its own, and this only sums what the finding says about it — how the parents
  # lean, and the descriptive ladder and income share of each arm.
  class Logic
    CAPABILITY = "H-capability-L"
    DEEP = "H-deep"
    STONES = "H-stones"
    COMPLEXITY = "H-complexity"

    # How one test's parents lean: more pairs favouring the full arm, all measured pairs tied,
    # or more pairs favouring the control. A parent whose favouring and against pairs balance
    # off a tie leans neither way and is counted in none.
    Leaning = Data.define(:full, :tied, :control)

    # The descriptive estimate of the share of income that came from tasks, over the full
    # children it is read for.
    IncomeShare = Data.define(:mean, :low, :high)

    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :any?, :interim?, :arms, :tests, to: :report

    def test(hypothesis) = tests.find { |test| test.hypothesis == hypothesis }

    def kept(hypothesis) = sensitivity(report.kept_tests, hypothesis, Lab::LogicReading::KEPT_SUFFIX)

    def unpiloted(hypothesis) = sensitivity(report.unpiloted_tests, hypothesis, Lab::LogicReading::UNPILOTED_SUFFIX)

    def capability = test(CAPABILITY)

    def deep = test(DEEP)

    def stones = test(STONES)

    def complexity = test(COMPLEXITY)

    def shown?(test) = test.outcome == :held

    def deep_climbed? = shown?(deep)

    def leaning(test)
      rows = test.comparison.agreement.select { |row| (row.treatment + row.continuation + row.ties).positive? }
      Leaning.new(full: rows.count { |row| row.treatment > row.continuation },
                  tied: rows.count { |row| row.treatment.zero? && row.continuation.zero? },
                  control: rows.count { |row| row.continuation > row.treatment })
    end

    def parent_count = report.children.map(&:parent_id).uniq.size

    # Whether every parent's measured pairs all favour the full arm.
    def unanimous?(test) = test.comparison.agreement.all? { |row| row.continuation.zero? && row.ties.zero? }

    # The shown tests that one or two parents carry, by the leave-out rule.
    def carried_tests = tests.select { |test| test.comparison.carried_by.any? }

    def shown_tests = tests.select { |test| shown?(test) }

    def full_arm = arm(:full)

    def deep_only_arm = arm(:deep_only)

    def none_arm = arm(:none)

    # How many of an arm's children's worlds held a rung at the descriptive line.
    def reached(arm, task) = arm.ladder.find { |rung| rung.task == task }.reached

    # The rungs below the deep ones, those a NAND circuit computes reading each input once.
    def read_once_tasks = Lab::LogicReading::TASKS - Lab::LogicReading::DEEP_TASKS

    def deep_children(arm) = arm.children.count(&:climbed_deep?)

    def stepping_stones(arm) = arm.children.count(&:stepping_stone?)

    def extinct_children(arm) = arm.children.count(&:extinct?)

    def relapsed_children(arm) = arm.children.count(&:settled_relapse?)

    def income_share
      shares = full_arm.children.filter_map(&:income_share)
      return nil if shares.empty?

      IncomeShare.new(mean: shares.sum / shares.size, low: shares.min, high: shares.max)
    end

    private

    def arm(key) = arms.find { |candidate| candidate.treatment.key == key }

    def sensitivity(readings, hypothesis, suffix) = readings.find { |test| test.hypothesis == "#{hypothesis}#{suffix}" }
  end
end
