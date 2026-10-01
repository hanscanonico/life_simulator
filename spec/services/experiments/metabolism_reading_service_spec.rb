# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::MetabolismReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { metabolism_experiment }
  let!(:parents) { [metabolism_parent, metabolism_parent] }
  let(:reward) { metabolism_children(experiment, reward: true) }
  let(:no_reward) { metabolism_children(experiment, reward: false) }

  def test(hypothesis) = report.tests.find { |candidate| candidate.hypothesis == hypothesis }

  before { Experiments::DescendantSweepBuilderService.call(experiment) }

  it "applies to the metabolism sweep alone" do
    expect([experiment, create(:experiment, slug: "from-emerged")].map { |sweep| described_class.applies_to?(sweep) })
      .to eq([true, false])
  end

  it "names the arms for the reward" do
    expect(report.arms.map(&:name)).to eq(["reward", "no reward"])
  end

  it "reads the three hypotheses on the rewarded arm" do
    expect(report.tests.map { |candidate| [candidate.hypothesis, candidate.treatment.name] })
      .to eq([["H-capability", "reward"], ["H-ladder", "reward"], ["H-complexity", "reward"]])
  end

  context "with no child sampled yet" do
    it "is interim and every test reads no measured pairs" do
      expect(report).to be_interim
      expect(report.tests.map(&:outcome)).to all(eq(:no_pairs))
    end
  end

  context "with every child finished, the rewarded arm more capable and more complex" do
    before do
      reward.each_with_index do |run, index|
        metabolism_sample(run, capability: 3, loop: index < 3 ? 1 : 0, last_count: 130,
                               task_shares: { "echo" => 0.5 })
      end
      no_reward.each { |run| metabolism_sample(run) }
    end

    it "is final" do
      expect(report).not_to be_interim
      expect(report.to_text).to start_with("metabolism reading, final (Metabolism: imports an objective)\n")
    end

    it "shows H-capability on six discordant pairs" do
      expect(test("H-capability").comparison)
        .to have_attributes(outcome: :held, measured_count: 6, favouring: 6, against: 0, p_value: Rational(1, 64))
    end

    it "states H-capability as carried by either parent, since three pairs alone fall short" do
      expect(test("H-capability").comparison.carried_by).to eq(parents.map { |parent| [parent.id] })
    end

    it "reads H-ladder not shown on three discordant pairs" do
      expect(test("H-ladder")).to have_attributes(outcome: :not_shown, outcome_label: "not shown")
      expect(test("H-ladder").comparison).to have_attributes(favouring: 3, against: 0, ties: 3)
    end

    it "shows H-complexity where the rewarded children rise and their twins do not" do
      expect(test("H-complexity").comparison).to have_attributes(outcome: :held, favouring: 6)
    end

    it "counts each arm" do
      expect(report.arms.map(&:cells)).to eq([["reward", 6, 6, 0, 0, 6, 0, 0, 6, 6],
                                              ["no reward", 6, 6, 0, 0, 6, 0, 0, 6, 0]])
    end

    it "pairs each reward child with its twin of the same parent and seed" do
      expect(report.pairs.map { |child, twin| [child.run_id, twin.run_id] })
        .to eq(reward.map(&:id).zip(no_reward.map(&:id)))
    end

    it "tables the ladder per arm: the tasks its worlds held and their median first epoch" do
      echo, *rest = report.arms.first.ladder
      expect(echo).to have_attributes(task: "echo", reached: 6, median_first_epoch: 1_010)
      expect(rest.map(&:reached)).to all(eq(0))
      expect(report.arms.last.ladder.map(&:median_first_epoch)).to all(be_nil)
    end

    it "gives each parent's agreement" do
      expect(test("H-ladder").agreement_cells)
        .to eq([["H-ladder", "reward", parents.first.id, 3, 0, 0, 0], ["H-ladder", "reward", parents.last.id, 0, 0, 3, 0]])
    end

    context "with the first parent among the piloted ones" do
      before { stub_const("Lab::MetabolismReading::PILOT_PARENTS", [parents.first.id]) }

      it "re-reads every test without its pairs, beside the tests it leaves unchanged" do
        expect(report.unpiloted_tests.map { |candidate| [candidate.hypothesis, candidate.outcome] })
          .to eq([["H-capability, unpiloted parents", :not_shown], ["H-ladder, unpiloted parents", :refuted],
                  ["H-complexity, unpiloted parents", :not_shown]])
        expect(report.unpiloted_tests.map { |candidate| candidate.comparison.measured_count }).to eq([3, 3, 3])
        expect(test("H-capability").outcome).to eq(:held)
        expect(report.to_text).to match(/H-capability, unpiloted parents\s+reward\s+3\s+3\s+0\s+0\s+0\.125\s+not shown/)
      end
    end

    it "estimates the share of income the tasks pay" do
      rows = report.children.group_by { |child| child.treatment.name }

      expect(rows.fetch("reward").map(&:income_share)).to all(be_within(1e-9).of(128.0 / 1_152))
      expect(rows.fetch("no reward").map(&:income_share)).to all(eq(0.0))
    end

    it "prints the tests and writes CSV" do
      expect(report.to_text).to match(/H-capability\s+reward\s+6\s+6\s+0\s+0\s+0\.0156\s+shown/)
      expect(CSV.parse(report.to_csv)).to include(Lab::MetabolismReading::CHILD_COLUMNS,
                                                  Lab::MetabolismReading::TEST_COLUMNS)
    end
  end

  context "with the unpaid twins as capable as the rewarded children" do
    before { experiment.runs.each { |run| metabolism_sample(run, capability: 2) } }

    it "refutes H-capability on pairs that all tie" do
      expect(test("H-capability")).to have_attributes(outcome: :refuted, outcome_label: "refuted")
    end
  end

  context "with the twins ahead on more pairs than the rewarded children" do
    before do
      reward.each_with_index { |run, index| metabolism_sample(run, capability: index.zero? ? 3 : 1) }
      no_reward.each { |run| metabolism_sample(run, capability: 2) }
    end

    it "refutes H-capability" do
      expect(test("H-capability").comparison).to have_attributes(outcome: :refuted, favouring: 1, against: 5)
    end
  end

  context "with a rewarded child extinct" do
    before do
      reward.each_with_index { |run, index| metabolism_sample(run, capability: 3, share: index.zero? ? 0.05 : 0.9) }
      no_reward.each { |run| metabolism_sample(run) }
    end

    it "leaves its pair out of every test" do
      expect(report.tests.map { |candidate| candidate.comparison.measured_count }).to eq([5, 5, 5])
      expect(report.arms.first.cells.values_at(3, 4)).to eq([1, 1])
    end
  end

  context "with an unpaid twin relapsing past the settling window and recovering" do
    before do
      reward.each { |run| metabolism_sample(run, capability: 3) }
      dip = ->(at) { (150..152).cover?(at) ? 0.05 : 0.9 }
      no_reward.each_with_index { |run, index| metabolism_sample(run, share: index.zero? ? dip : 0.9) }
    end

    it "leaves the pair out of H-complexity alone" do
      expect(report.tests.map { |candidate| candidate.comparison.measured_count }).to eq([6, 6, 5])
      expect(report.children.find { |child| child.run_id == no_reward.first.id }.heldout.settled_relapse_epoch)
        .to eq(2_510)
    end
  end

  context "with a rewarded child that dipped just before its last settled decile" do
    before do
      dip = ->(at) { (180..189).cover?(at) ? 0.05 : 0.9 }
      reward.each_with_index { |run, index| metabolism_sample(run, capability: 3, share: index.zero? ? dip : 0.9) }
      no_reward.each { |run| metabolism_sample(run) }
    end

    it "cuts extinction's last decile from the settled samples, so the child is not extinct" do
      child = report.children.find { |row| row.run_id == reward.first.id }

      expect(child).to have_attributes(extinct?: false, settled_relapse?: true)
      expect(test("H-capability").comparison.measured_count).to eq(6)
    end
  end

  context "with a crash inside the settling window" do
    before do
      experiment.runs.each { |run| metabolism_sample(run, share: ->(at) { (5..7).cover?(at) ? 0.0 : 0.9 }) }
    end

    it "reads no settled relapse" do
      expect(report.children.map { |child| child.heldout.settled_relapse_epoch }).to all(be_nil)
    end
  end

  context "with children that sampled no task capability" do
    before do
      experiment.runs.each do |run|
        insert_own_samples(run, Array.new(200) { { "replicator_share" => 0.9 } })
        run.update!(status: "finished")
      end
    end

    it "reads no measured pairs" do
      expect(report.tests.map(&:outcome_label)).to all(eq("no measured pairs"))
    end
  end

  context "with a child still running" do
    before do
      experiment.runs.each { |run| metabolism_sample(run) }
      reward.first.update!(status: "running")
    end

    it "is interim" do
      expect(report.heading)
        .to eq("metabolism reading, interim: not every child of every qualifying parent has finished " \
               "(Metabolism: imports an objective)")
    end
  end

  context "with a rewarded child climbing a loop rung after INC" do
    before do
      metabolism_sample(reward.first, task_shares: { "echo" => 0.5, "inc" => ->(at) { at >= 20 ? 0.2 : 0.0 },
                                                     "add" => ->(at) { at >= 60 ? 0.15 : 0.0 } })
    end

    it "reads the ladder's first epochs and the stepping stone" do
      child = report.children.find { |row| row.run_id == reward.first.id }

      expect(child.metabolism.first_epochs).to include("echo" => 1_010, "inc" => 1_210, "add" => 1_610, "mul" => nil)
      expect(report.arms.first.cells.values_at(6, 7)).to eq([1, 1])
    end
  end
end
