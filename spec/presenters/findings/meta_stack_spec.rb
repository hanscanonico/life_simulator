# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::MetaStack do
  subject(:reading) { described_class.build(Experiments::MetaStackReadingService.call(experiment: experiment)) }

  let(:experiment) { meta_stack_experiment }
  let(:logic) { logic_experiment }
  let!(:parents) { Array.new(4) { metabolism_parent } }
  let(:stack) { meta_stack_children(experiment, :meta_stack) }
  let(:deep_seeds) { stack.first(5) }

  before do
    Experiments::DescendantSweepBuilderService.call(logic)
    Experiments::DescendantSweepBuilderService.call(experiment)
    stack.each do |run|
      deep = deep_seeds.include?(run)
      meta_stack_sample(run, capability: 3, deep: deep ? 1 : 0,
                             task_shares: { "echo" => 0.5, "xor" => deep ? 0.2 : 0.0 })
    end
    (experiment.runs + logic.runs).each { |run| meta_stack_sample(run) if run.samples.none? }
  end

  it "finds each pre-registered test by its hypothesis" do
    expect([reading.deep, reading.stones, reading.stack, reading.capability].map(&:hypothesis))
      .to eq(%w[H-deep-Ms H-stones-Ms H-stack H-capability-M])
  end

  it "shows the deep rungs against every control the stack arm faces, and refutes the in-place tape" do
    expect(reading.tests.to_h { |test| [test.hypothesis, test.outcome] })
      .to eq("H-deep-Ms" => :held, "H-stones-Ms" => :held, "H-stack" => :held, "H-deep-M" => :refuted,
             "H-decouple" => :refuted, "H-capability-M" => :held)
    expect(reading).to be_assembled
  end

  it "finds each test's re-readings with the extinct pairs kept and without the piloted parents" do
    expect([reading.kept("H-deep-Ms"), reading.unpiloted("H-deep-Ms")].map(&:hypothesis))
      .to eq(["H-deep-Ms, extinct kept", "H-deep-Ms, unpiloted parents"])
  end

  it "reads capability as unanimous across the parents, and the deep rungs not" do
    expect(reading.parent_count).to eq(4)
    expect(reading).to be_unanimous(reading.capability)
    expect(reading).not_to be_unanimous(reading.deep)
  end

  it "counts how the parents lean on each test" do
    expect(reading.leaning(reading.deep)).to eq(described_class::Leaning.new(treated: 2, tied: 2, control: 0))
    expect(reading.leaning(reading.test("H-deep-M"))).to eq(described_class::Leaning.new(treated: 0, tied: 4,
                                                                                         control: 0))
  end

  it "lists the deep tests the two deep parents carry" do
    expect(reading.carried_tests.map(&:hypothesis)).to eq(%w[H-deep-Ms H-stones-Ms H-stack])
    expect(reading.deep.comparison.carried_by).to include([parents.first.id])
  end

  it "lists the re-readings one or two parents carry" do
    expect(reading.carried_sensitivities.map(&:hypothesis))
      .to include("H-deep-Ms, extinct kept", "H-deep-Ms, unpiloted parents")
  end

  context "with the piloted parents among the deep ones" do
    before { stub_const("Lab::MetaStackReading::PILOT_PARENTS", [parents.first.id]) }

    it "reads the unpiloted re-reading without their pairs" do
      expect(reading.unpiloted("H-deep-Ms").comparison).to have_attributes(favouring: 2, measured_count: 9)
    end
  end

  it "lists the deep children in (parent, seed) order, from two parents" do
    expect(reading.deep_children.map(&:run_id)).to eq(deep_seeds.map(&:id))
    expect(reading.deep_parent_count).to eq(2)
  end

  it "counts the deep and extinct children of each arm" do
    expect(reading.arms.map { |arm| [arm.name, reading.deep_count(arm), reading.extinct_count(arm)] })
      .to eq([["meta-stack", 5, 0], ["meta-stack-deep-only", 0, 0], ["meta-inplace", 0, 0],
              ["logic-none", 0, 0], ["logic-full", 0, 0]])
  end

  it "takes the stack arm as the meta-stack children" do
    expect(reading.stack_arm.children.map(&:run_id)).to match_array(stack.map(&:id))
  end
end
