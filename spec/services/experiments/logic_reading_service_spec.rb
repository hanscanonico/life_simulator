# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::LogicReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { logic_experiment }
  let!(:parents) { [metabolism_parent, metabolism_parent] }
  let(:full) { logic_children(experiment, :full) }
  let(:deep_only) { logic_children(experiment, :deep_only) }
  let(:none) { logic_children(experiment, :none) }

  def test(hypothesis, tests = report.tests) = tests.find { |candidate| candidate.hypothesis == hypothesis }

  def outcomes(tests) = tests.to_h { |candidate| [candidate.hypothesis, candidate.outcome] }

  before { Experiments::DescendantSweepBuilderService.call(experiment) }

  it "applies to the logic sweep alone" do
    expect([experiment, create(:experiment, slug: "metabolism")].map { |sweep| described_class.applies_to?(sweep) })
      .to eq([true, false])
  end

  it "names the three arms" do
    expect(report.arms.map(&:name)).to eq(%w[full deep-only none])
  end

  it "reads the four hypotheses on the full arm, H-stones against deep-only and the rest against none" do
    expect(report.tests.map { |candidate| [candidate.hypothesis, candidate.treatment.name, candidate.control.name] })
      .to eq([%w[H-capability-L full none], %w[H-deep full none], %w[H-stones full deep-only],
              %w[H-complexity full none]])
  end

  it "reads every test again with the extinct pairs kept and without the piloted parents" do
    expect(report.readings.map { |readings| readings.map(&:hypothesis) }.second)
      .to eq(["H-deep", "H-deep, extinct kept", "H-deep, unpiloted parents"])
  end

  context "with no child sampled yet" do
    it "is interim and every test reads no measured pairs" do
      expect(report).to be_interim
      expect(report.heading).to eq("logic reading, interim: not every child of every qualifying parent has " \
                                   "finished (Logic: imports an objective and a primitive)")
      expect([report.tests, report.kept_tests, report.unpiloted_tests].flatten.map(&:outcome)).to all(eq(:no_pairs))
    end
  end

  context "with every child finished, the full arm more capable, deeper and more complex" do
    before do
      full.each do |run|
        logic_sample(run, capability: 4, deep: 1, last_count: 130, task_shares: { "echo" => 0.5 })
      end
      deep_only.each { |run| logic_sample(run, capability: 1, task_shares: { "echo" => 0.5, "xor" => 0.2 }) }
      none.each { |run| logic_sample(run) }
    end

    it "is final" do
      expect(report).not_to be_interim
      expect(report.to_text).to start_with("logic reading, final (Logic: imports an objective and a primitive)\n")
    end

    it "shows every test on six discordant pairs" do
      expect(report.tests.map(&:comparison))
        .to all(have_attributes(outcome: :held, measured_count: 6, favouring: 6, against: 0, p_value: Rational(1, 64)))
    end

    it "states each test as carried by either parent, since three pairs alone fall short" do
      expect(test("H-deep").comparison.carried_by).to eq(parents.map { |parent| [parent.id] })
    end

    it "reads the sensitivity readings the same where no child is extinct" do
      expect(report.kept_tests.map(&:outcome)).to all(eq(:held))
    end

    it "counts each arm" do
      expect(report.arms.map(&:cells)).to eq([["full", 6, 6, 0, 0, 6, 0, 0, 6, 6],
                                              ["deep-only", 6, 6, 0, 0, 6, 6, 0, 6, 0],
                                              ["none", 6, 6, 0, 0, 6, 0, 0, 6, 0]])
    end

    it "pairs each full child with its deep-only and its none twin" do
      expect(report.pairs.map { |triple| triple.map(&:run_id) })
        .to eq(full.map(&:id).zip(deep_only.map(&:id), none.map(&:id)))
    end

    it "estimates the share of income the paid rungs bring, at or above each arm's floor" do
      rows = report.children.group_by { |child| child.treatment.name }

      expect(rows.fetch("full").map(&:income_share)).to all(be_within(1e-9).of(128.0 / 1_152))
      expect(rows.fetch("deep-only").map(&:income_share)).to all(be_within(1e-9).of(409.6 / 1_433.6))
      expect(rows.fetch("none").map(&:income_share)).to all(eq(0.0))
    end

    it "gives each parent's agreement against the named control" do
      expect(test("H-stones").agreement_cells)
        .to eq(parents.map { |parent| ["H-stones", "full", "deep-only", parent.id, 3, 0, 0, 0] })
    end

    it "prints the tests and their sensitivity readings, and writes CSV" do
      expect(report.to_text)
        .to match(/H-stones\s+full\s+deep-only\s+6\s+6\s+0\s+0\s+0\.0156\s+shown/)
        .and match(/H-deep, extinct kept\s+full\s+none\s+6\s+6\s+0\s+0\s+0\.0156\s+shown/)
      expect(CSV.parse(report.to_csv)).to include(Lab::LogicReading::CHILD_COLUMNS, Lab::LogicReading::TEST_COLUMNS)
    end

    context "with the first parent among the piloted ones" do
      before { stub_const("Lab::LogicReading::PILOT_PARENTS", [parents.first.id]) }

      it "re-reads every test without its pairs, beside the tests it leaves unchanged" do
        expect(outcomes(report.unpiloted_tests))
          .to eq("H-capability-L, unpiloted parents" => :not_shown, "H-deep, unpiloted parents" => :not_shown,
                 "H-stones, unpiloted parents" => :not_shown, "H-complexity, unpiloted parents" => :not_shown)
        expect(test("H-deep").outcome).to eq(:held)
      end
    end
  end

  context "with half the full children reaching a deep rung and every deep-only child reaching one" do
    before do
      full.each_with_index { |run, index| logic_sample(run, capability: 3, deep: index < 3 ? 1 : 0) }
      deep_only.each { |run| logic_sample(run, capability: 1, deep: 1) }
      none.each { |run| logic_sample(run) }
    end

    it "reads H-deep not shown on three discordant pairs" do
      expect(test("H-deep")).to have_attributes(outcome: :not_shown, outcome_label: "not shown")
      expect(test("H-deep").comparison).to have_attributes(favouring: 3, against: 0, ties: 3)
    end

    it "refutes H-stones where deep-only climbs as often" do
      expect(test("H-stones").comparison).to have_attributes(outcome: :refuted, favouring: 0, against: 3, ties: 3)
    end
  end

  context "with every arm as capable and as flat" do
    before { experiment.runs.each { |run| logic_sample(run, capability: 2) } }

    it "refutes every test on pairs that all tie" do
      expect(report.tests.map(&:outcome_label)).to all(eq("refuted"))
      expect(report.tests.map { |candidate| candidate.comparison.ties }).to all(eq(6))
    end
  end

  context "with the none arm ahead on more pairs than the full arm" do
    before do
      full.each_with_index { |run, index| logic_sample(run, capability: index.zero? ? 3 : 1, first_count: 130) }
      deep_only.each { |run| logic_sample(run) }
      none.each { |run| logic_sample(run, capability: 2, last_count: 130) }
    end

    it "refutes H-capability-L and H-complexity" do
      expect(test("H-capability-L").comparison).to have_attributes(outcome: :refuted, favouring: 1, against: 5)
      expect(test("H-complexity").comparison).to have_attributes(outcome: :refuted, favouring: 0, against: 6)
    end
  end

  context "with every full child a world of partial copiers, capable but reading as extinct" do
    before do
      full.each { |run| logic_sample(run, capability: 4, deep: 1, last_count: 130, share: 0.05) }
      deep_only.each { |run| logic_sample(run) }
      none.each { |run| logic_sample(run) }
    end

    it "leaves every pair out of the pre-registered tests" do
      expect(report.tests.map(&:outcome)).to all(eq(:no_pairs))
      expect(report.arms.first.cells.values_at(3, 4)).to eq([6, 6])
    end

    it "reads each test with the extinct pairs kept, the settled relapses included, as a sensitivity reading" do
      expect(outcomes(report.kept_tests))
        .to eq("H-capability-L, extinct kept" => :held, "H-deep, extinct kept" => :held,
               "H-stones, extinct kept" => :held, "H-complexity, extinct kept" => :held)
    end
  end

  context "with one full child extinct" do
    before do
      full.each_with_index { |run, index| logic_sample(run, capability: 3, share: index.zero? ? 0.05 : 0.9) }
      deep_only.each { |run| logic_sample(run) }
      none.each { |run| logic_sample(run) }
    end

    it "leaves its pair out of every test and keeps it in every sensitivity reading" do
      expect(report.tests.map { |candidate| candidate.comparison.measured_count }).to eq([5, 5, 5, 5])
      expect(report.kept_tests.map { |candidate| candidate.comparison.measured_count }).to eq([6, 6, 6, 6])
    end
  end

  context "with children that sampled no logic capability" do
    before do
      experiment.runs.each do |run|
        insert_own_samples(run, Array.new(200) { { "replicator_share" => 0.9 } })
        run.update!(status: "finished")
      end
    end

    it "reads no measured pairs on the capability tests" do
      expect(report.tests.first(3).map(&:outcome_label)).to all(eq("no measured pairs"))
    end
  end

  context "with a child still running" do
    before do
      experiment.runs.each { |run| logic_sample(run) }
      full.first.update!(status: "running")
    end

    it "is interim" do
      expect(report).to be_interim
      expect(report.heading).to start_with("logic reading, interim")
    end
  end

  context "with a full child climbing XOR after OR" do
    before do
      logic_sample(full.first, task_shares: { "echo" => 0.5, "or" => ->(at) { at >= 20 ? 0.2 : 0.0 },
                                              "xor" => ->(at) { at >= 60 ? 0.15 : 0.0 } })
    end

    it "reads the ladder's first epochs under the persistence rule and the stepping stone" do
      child = report.children.find { |row| row.run_id == full.first.id }

      expect(child.logic.first_epochs).to include("echo" => 1_010, "or" => 1_210, "xor" => 1_610, "equ" => nil)
      expect(report.arms.first.cells.values_at(6, 7)).to eq([1, 1])
      expect(report.arms.first.ladder.find { |rung| rung.task == "xor" })
        .to have_attributes(reached: 1, median_first_epoch: 1_610)
    end
  end
end
