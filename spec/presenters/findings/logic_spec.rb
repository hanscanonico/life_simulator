# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::Logic do
  subject(:reading) { described_class.build(Experiments::LogicReadingService.call(experiment: experiment)) }

  let(:experiment) { logic_experiment }
  let(:full) { logic_children(experiment, :full) }
  let(:deep_only) { logic_children(experiment, :deep_only) }
  let(:none) { logic_children(experiment, :none) }

  before do
    4.times { metabolism_parent }
    Experiments::DescendantSweepBuilderService.call(experiment)
    full.each_with_index do |run, index|
      logic_sample(run, capability: 3, last_count: index.even? ? 130 : 100,
                        task_shares: { "echo" => 0.5, "not" => 0.2, "nand" => index.zero? ? 0.2 : 0.0 })
    end
    [deep_only, none].each do |arm|
      arm.each_with_index { |run, index| logic_sample(run, task_shares: { "echo" => index.zero? ? 0.2 : 0.0 }) }
    end
  end

  it "finds each pre-registered test by its hypothesis" do
    expect([reading.capability, reading.deep, reading.stones, reading.complexity].map(&:hypothesis))
      .to eq(%w[H-capability-L H-deep H-stones H-complexity])
  end

  it "shows capability, refutes the deep rungs and the stepping stones on ties and shows complexity" do
    expect(reading.tests.map(&:outcome)).to eq(%i[held refuted refuted held])
    expect(reading).not_to be_deep_climbed
  end

  it "finds each test's re-readings with the extinct pairs kept and without the piloted parents" do
    expect([reading.kept("H-deep"), reading.unpiloted("H-deep")].map(&:hypothesis))
      .to eq(["H-deep, extinct kept", "H-deep, unpiloted parents"])
  end

  it "reads capability as unanimous across the parents, and complexity not" do
    expect(reading.parent_count).to eq(4)
    expect(reading).to be_unanimous(reading.capability)
    expect(reading).not_to be_unanimous(reading.complexity)
  end

  it "counts how the parents lean on each test" do
    expect(reading.leaning(reading.deep)).to eq(described_class::Leaning.new(full: 0, tied: 4, control: 0))
    expect(reading.leaning(reading.capability)).to eq(described_class::Leaning.new(full: 4, tied: 0, control: 0))
  end

  it "lists the shown tests one or two parents carry" do
    expect(reading.shown_tests.map(&:hypothesis)).to eq(%w[H-capability-L H-complexity])
    expect(reading.carried_tests.map(&:hypothesis)).to eq(%w[H-complexity])
  end

  it "names the three arms" do
    expect([reading.full_arm, reading.deep_only_arm, reading.none_arm].map(&:name)).to eq(%w[full deep-only none])
  end

  it "counts the rungs each arm's worlds held" do
    expect(%w[echo not nand and xor].map { |task| reading.reached(reading.full_arm, task) }).to eq([12, 12, 1, 0, 0])
    expect(reading.reached(reading.none_arm, "echo")).to eq(1)
  end

  it "takes the read-once rungs as every rung below the deep ones" do
    expect(reading.read_once_tasks).to eq(%w[echo not nand and orn or andn nor])
  end

  it "counts no deep rung, no stepping stone, no extinction and no relapse in any arm" do
    expect(reading.arms.map do |arm|
      [reading.deep_children(arm), reading.stepping_stones(arm), reading.extinct_children(arm),
       reading.relapsed_children(arm)]
    end).to eq([[0, 0, 0, 0]] * 3)
  end

  it "summarises the full children's estimated income share from tasks" do
    shares = reading.full_arm.children.map(&:income_share)

    expect(reading.income_share).to have_attributes(mean: shares.sum / shares.size, low: shares.min, high: shares.max)
  end

  it "has no income share without a full child" do
    report = reading.report.with(arms: [reading.full_arm.with(children: []), *reading.arms.drop(1)])

    expect(described_class.build(report).income_share).to be_nil
  end
end
