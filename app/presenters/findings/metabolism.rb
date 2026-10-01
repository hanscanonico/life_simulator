# frozen_string_literal: true

module Findings
  # The metabolism sweep's pre-registered reading (DESIGN §1.3 item 15) as the finding that
  # states it. `report` is the sweep's Lab::MetabolismReading::Report: every verdict, count,
  # p and carrying parent is its own, and this only sums what the finding says about it —
  # how the parents lean, and the descriptive ladder and income share of each arm.
  class Metabolism
    CAPABILITY = "H-capability"
    LADDER = "H-ladder"
    COMPLEXITY = "H-complexity"

    # How one test's parents lean: more pairs favouring the reward, all measured pairs tied,
    # or more pairs favouring the twin. A parent whose favouring and against pairs balance
    # off a tie leans neither way and is counted in none.
    Leaning = Data.define(:reward, :tied, :twin)

    # The descriptive estimate of the share of income that came from tasks, over the reward
    # children it is read for.
    IncomeShare = Data.define(:mean, :low, :high)

    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :any?, :interim?, :arms, to: :report

    def test(hypothesis) = report.tests.find { |test| test.hypothesis == hypothesis }

    def unpiloted(hypothesis)
      report.unpiloted_tests.find { |test| test.hypothesis == "#{hypothesis}#{Lab::MetabolismReading::UNPILOTED_SUFFIX}" }
    end

    def capability = test(CAPABILITY)

    def ladder = test(LADDER)

    def complexity = test(COMPLEXITY)

    def shown?(test) = test.outcome == :held

    def ladder_climbed? = shown?(ladder)

    def leaning(test)
      rows = test.comparison.agreement.select { |row| (row.treatment + row.continuation + row.ties).positive? }
      Leaning.new(reward: rows.count { |row| row.treatment > row.continuation },
                  tied: rows.count { |row| row.treatment.zero? && row.continuation.zero? },
                  twin: rows.count { |row| row.continuation > row.treatment })
    end

    def parent_count = report.children.map(&:parent_id).uniq.size

    # Whether every parent's measured pairs all favour the reward.
    def unanimous?(test) = test.comparison.agreement.all? { |row| row.continuation.zero? && row.ties.zero? }

    # The shown tests that one or two parents carry, by the leave-out rule.
    def carried_tests = report.tests.select { |test| test.comparison.carried_by.any? }

    def shown_tests = report.tests.select { |test| shown?(test) }

    def reward_arm = arms.first

    def twin_arm = arms.second

    # How many of an arm's children's worlds held a task at the descriptive line.
    def reached(arm, task) = arm.ladder.find { |rung| rung.task == task }.reached

    def loop_children(arm) = arm.children.count(&:climbed_loop?)

    def stepping_stones(arm) = arm.children.count(&:stepping_stone?)

    # The twins whose last-decile capability is not 0: computing the reward does not pay
    # for, held by a tenth of the world at the end of the run.
    def capable_twins
      twin_arm.children.select { |child| child.capability(Lab::MetabolismReading::CAPABILITY_KEY).to_i.positive? }
    end

    def income_share
      shares = reward_arm.children.filter_map(&:income_share)
      return nil if shares.empty?

      IncomeShare.new(mean: shares.sum / shares.size, low: shares.min, high: shares.max)
    end
  end
end
