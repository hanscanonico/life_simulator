# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::Metabolism do
  subject(:reading) { described_class.build(Experiments::MetabolismReadingService.call(experiment: experiment)) }

  let(:experiment) { metabolism_experiment }
  let(:reward) { metabolism_children(experiment, reward: true) }
  let(:no_reward) { metabolism_children(experiment, reward: false) }

  before do
    4.times { metabolism_parent }
    Experiments::DescendantSweepBuilderService.call(experiment)
    reward.each_with_index do |run, index|
      metabolism_sample(run, capability: 3, last_count: index.even? ? 130 : 100,
                             task_shares: { "echo" => 0.5, "inc" => 0.2, "dec" => index.zero? ? 0.2 : 0.0 })
    end
    no_reward.each_with_index do |run, index|
      metabolism_sample(run, capability: index.zero? ? 1 : 0, task_shares: { "echo" => index.zero? ? 0.2 : 0.0 })
    end
  end

  it "finds each pre-registered test by its hypothesis" do
    expect([reading.capability, reading.ladder, reading.complexity].map(&:hypothesis))
      .to eq(%w[H-capability H-ladder H-complexity])
  end

  it "shows capability, refutes the ladder on ties and shows complexity" do
    expect([reading.capability, reading.ladder, reading.complexity].map(&:outcome)).to eq(%i[held refuted held])
    expect(reading).not_to be_ladder_climbed
  end

  it "finds each test's re-reading without the piloted parents" do
    expect(reading.unpiloted("H-ladder").hypothesis).to eq("H-ladder, unpiloted parents")
  end

  it "reads capability as unanimous across the parents, and complexity not" do
    expect(reading.parent_count).to eq(4)
    expect(reading).to be_unanimous(reading.capability)
    expect(reading).not_to be_unanimous(reading.complexity)
  end

  it "counts how the parents lean on each test" do
    expect(reading.leaning(reading.ladder)).to eq(described_class::Leaning.new(reward: 0, tied: 4, twin: 0))
    expect(reading.leaning(reading.capability)).to eq(described_class::Leaning.new(reward: 4, tied: 0, twin: 0))
  end

  it "lists the shown tests one or two parents carry" do
    expect(reading.shown_tests.map(&:hypothesis)).to eq(%w[H-capability H-complexity])
    expect(reading.carried_tests.map(&:hypothesis)).to eq(%w[H-complexity])
  end

  it "counts the tasks each arm's worlds held" do
    expect(%w[echo inc dec add].map { |task| reading.reached(reading.reward_arm, task) }).to eq([12, 12, 1, 0])
    expect(reading.reached(reading.twin_arm, "echo")).to eq(1)
  end

  it "counts no loop task and no stepping stone in either arm" do
    expect(reading.arms.map { |arm| [reading.loop_children(arm), reading.stepping_stones(arm)] })
      .to eq([[0, 0], [0, 0]])
  end

  it "names the twins that held a task at the end of the run" do
    expect(reading.capable_twins.map(&:run_id)).to eq([no_reward.first.id])
  end

  it "summarises the reward children's estimated income share from tasks" do
    shares = reading.reward_arm.children.map(&:income_share)

    expect(reading.income_share).to have_attributes(mean: shares.sum / shares.size, low: shares.min, high: shares.max)
  end

  it "has no income share without a reward child" do
    report = reading.report.with(arms: [reading.reward_arm.with(children: []), reading.twin_arm])

    expect(described_class.build(report).income_share).to be_nil
  end
end
