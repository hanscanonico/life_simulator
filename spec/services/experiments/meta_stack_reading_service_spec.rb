# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::MetaStackReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { meta_stack_experiment }
  let(:logic) { logic_experiment }
  let!(:parents) { [metabolism_parent, metabolism_parent] }
  let(:stack) { meta_stack_children(experiment, :meta_stack) }
  let(:deep_only) { meta_stack_children(experiment, :meta_stack_deep_only) }
  let(:in_place) { meta_stack_children(experiment, :meta_inplace) }
  let(:none) { meta_stack_children(logic, :logic_none) }
  let(:full) { meta_stack_children(logic, :logic_full) }

  def test(hypothesis, tests = report.tests) = tests.find { |candidate| candidate.hypothesis == hypothesis }

  def outcomes(tests = report.tests) = tests.to_h { |candidate| [candidate.hypothesis, candidate.outcome] }

  # Samples every child of the five arms, each arm's options given by its key; the logic
  # sweep's deep-only children are sampled as well, and read nowhere.
  def sample_arms(arms = {})
    { meta_stack: stack, meta_stack_deep_only: deep_only, meta_inplace: in_place, logic_none: none,
      logic_full: full }.each do |key, runs|
      runs.each_with_index { |run, index| meta_stack_sample(run, **option_at(arms.fetch(key, {}), index)) }
    end
    logic_children(logic, :deep_only).each { |run| logic_sample(run, capability: 9, deep: 2) }
  end

  def option_at(options, index) = options.transform_values { |value| value.is_a?(Array) ? value[index] : value }

  before do
    Experiments::DescendantSweepBuilderService.call(logic)
    Experiments::DescendantSweepBuilderService.call(experiment)
  end

  it "applies to the meta-stack sweep alone" do
    expect([experiment, logic].map { |sweep| described_class.applies_to?(sweep) }).to eq([true, false])
  end

  it "names its three arms and the logic sweep's two twins" do
    expect(report.arms.map(&:name)).to eq(%w[meta-stack meta-stack-deep-only meta-inplace logic-none logic-full])
    expect(report.arms.map { |arm| arm.children.size }).to eq([6, 6, 6, 6, 6])
  end

  it "reads the six hypotheses, each on its treated arm against its control" do
    expect(report.tests.map { |candidate| [candidate.hypothesis, candidate.treatment.name, candidate.control.name] })
      .to eq([%w[H-deep-Ms meta-stack logic-none], %w[H-stones-Ms meta-stack meta-stack-deep-only],
              %w[H-stack meta-stack meta-inplace], %w[H-deep-M meta-inplace logic-none],
              %w[H-decouple meta-inplace logic-full], %w[H-capability-M meta-stack logic-none]])
  end

  it "reads every test again with the extinct pairs kept and without the piloted parents" do
    expect(report.readings.map { |readings| readings.map(&:hypothesis) }.fourth)
      .to eq(["H-deep-M", "H-deep-M, extinct kept", "H-deep-M, unpiloted parents"])
  end

  context "with no child sampled yet" do
    it "is interim and every test reads no measured pairs" do
      expect(report).to be_interim
      expect(report.heading).to start_with("meta-stack reading, interim: not every child of every qualifying " \
                                           "parent has finished, here and in the logic sweep (Meta-stack: imports " \
                                           "an objective, a primitive, a hereditary channel and a choice of the " \
                                           "primitive's semantics")
      expect([report.tests, report.kept_tests, report.unpiloted_tests].flatten.map(&:outcome)).to all(eq(:no_pairs))
    end
  end

  context "with every child of both sweeps finished, the stack deepest, then the in-place tape" do
    before do
      sample_arms(meta_stack: { capability: 5, deep: 2, task_shares: { "echo" => 0.5 },
                                meta: { "meta_inherit_rate" => 0.25, "meta_diversity" => 0.5,
                                        "logic_capability_replicating" => 1 } },
                  meta_inplace: { capability: 3, deep: 1 })
    end

    it "is final" do
      expect(report).not_to be_interim
      expect(report.to_text).to start_with("meta-stack reading, final (Meta-stack: imports an objective")
    end

    it "shows every test on six discordant pairs" do
      expect(report.tests.map(&:comparison))
        .to all(have_attributes(outcome: :held, measured_count: 6, favouring: 6, against: 0, p_value: Rational(1, 64)))
    end

    it "pairs every (parent, seed) across the five arms of the two sweeps" do
      expect(report.pairs.map { |parent_id, seed, *children| [parent_id, seed, *children.map(&:run_id)] })
        .to eq(stack.each_index.map do |index|
          [stack[index].parent_run_id, stack[index].seed,
           *[stack, deep_only, in_place, none, full].map { |arm| arm[index].id }]
        end)
    end

    it "gives each parent's agreement against the named control" do
      expect(test("H-decouple").agreement_cells)
        .to eq(parents.map { |parent| ["H-decouple", "meta-inplace", "logic-full", parent.id, 3, 0, 0, 0] })
    end

    it "reads the metabolism tape's descriptive medians beside Logic's" do
      row = report.children.find { |child| child.run_id == stack.first.id }

      expect(row.cells.last(3)).to eq([0.25, 0.5, 1])
      expect(CSV.parse(report.to_csv))
        .to include(Lab::MetaStackReading::CHILD_COLUMNS, Lab::MetaStackReading::PAIR_COLUMNS)
    end

    it "prints the tests and their sensitivity readings" do
      expect(report.to_text)
        .to match(/H-stack\s+meta-stack\s+meta-inplace\s+6\s+6\s+0\s+0\s+0\.0156\s+shown/)
        .and match(/H-deep-Ms, extinct kept\s+meta-stack\s+logic-none\s+6\s+6\s+0\s+0\s+0\.0156\s+shown/)
    end

    context "with the first parent among the piloted ones" do
      before { stub_const("Lab::MetaStackReading::PILOT_PARENTS", [parents.first.id]) }

      it "re-reads every test without its pairs, beside the tests it leaves unchanged" do
        expect(outcomes(report.unpiloted_tests).values).to all(eq(:not_shown))
        expect(report.unpiloted_tests.map { |candidate| candidate.comparison.measured_count }).to all(eq(3))
        expect(outcomes.values).to all(eq(:held))
      end
    end
  end

  context "with every arm as capable and as shallow" do
    before { sample_arms(Lab::MetaStackReading::TREATMENT_NAMES.keys.index_with { { capability: 2 } }) }

    it "refutes every test on pairs that all tie" do
      expect(outcomes.values).to all(eq(:refuted))
      expect(report.tests.map { |candidate| candidate.comparison.ties }).to all(eq(6))
    end
  end

  context "with half of the stack children and the same half of the in-place children reaching a deep rung" do
    before do
      half = [1, 1, 1, 0, 0, 0]
      sample_arms(meta_stack: { capability: 3, deep: half }, meta_inplace: { capability: 3, deep: half })
    end

    it "reads the tests against unpaid, deep-only and woven twins not shown on three discordant pairs" do
      expect(outcomes.slice("H-deep-Ms", "H-stones-Ms", "H-deep-M", "H-decouple").values).to all(eq(:not_shown))
      expect(test("H-deep-Ms").comparison).to have_attributes(favouring: 3, against: 0, ties: 3)
    end

    it "refutes H-stack where the in-place tape climbs as often" do
      expect(test("H-stack").comparison).to have_attributes(outcome: :refuted, favouring: 0, against: 0, ties: 6)
    end

    it "shows H-capability-M" do
      expect(test("H-capability-M").outcome).to eq(:held)
    end
  end

  context "with the deep-only, the unpaid and the woven twins deeper than the arms they control" do
    before do
      sample_arms(meta_stack_deep_only: { deep: 1 }, logic_none: { capability: 4, deep: 1 },
                  logic_full: { deep: 1 })
    end

    it "refutes every test" do
      expect(outcomes.values).to all(eq(:refuted))
      expect(test("H-stones-Ms").comparison).to have_attributes(favouring: 0, against: 6)
      expect(test("H-decouple").comparison).to have_attributes(favouring: 0, against: 6)
    end
  end

  context "with one unpaid twin extinct" do
    before do
      sample_arms(meta_stack: { capability: 5, deep: 1 }, meta_inplace: { deep: 1 },
                  logic_none: { share: [0.05, 0.9, 0.9, 0.9, 0.9, 0.9] })
    end

    it "leaves its pairs out of the tests against the unpaid arm and keeps them in the sensitivity reading" do
      against_none = %w[H-deep-Ms H-deep-M H-capability-M]

      expect(against_none.map { |hypothesis| test(hypothesis).comparison.measured_count }).to eq([5, 5, 5])
      expect(against_none.map { |hypothesis| test("#{hypothesis}, extinct kept", report.kept_tests) }
                         .map { |candidate| candidate.comparison.measured_count }).to eq([6, 6, 6])
      expect(test("H-stones-Ms").comparison.measured_count).to eq(6)
    end
  end

  context "with one woven twin never seeded" do
    before do
      sample_arms(meta_inplace: { deep: 1 })
      full.first.destroy!
    end

    it "reads the pair as unmeasured and prints the missing child as a gap" do
      expect(test("H-decouple").comparison).to have_attributes(measured_count: 5, favouring: 5)
      expect(test("H-decouple").agreement_cells.first.last).to eq(1)
      expect(report.pairs.first.last).to be_nil
    end
  end

  context "with the logic sweep not seeded at all" do
    before do
      logic.destroy!
      sample_arms(meta_stack: { capability: 5, deep: 1 })
    end

    it "reads no pairs against the twins, the tests within the sweep as they fall, and stays interim" do
      expect(outcomes).to include("H-deep-Ms" => :no_pairs, "H-decouple" => :no_pairs, "H-capability-M" => :no_pairs,
                                  "H-stones-Ms" => :held, "H-stack" => :held)
      expect(report.arms.last(2).map { |arm| arm.children.size }).to eq([0, 0])
      expect(report).to be_interim
    end
  end

  context "with every meta-stack child finished and a logic twin still running" do
    before do
      sample_arms
      full.first.update!(status: "running")
    end

    it "is interim" do
      expect(report).to be_interim
      expect(report.heading).to start_with("meta-stack reading, interim")
    end
  end

  context "with every logic child finished and a meta-stack child still running" do
    before do
      sample_arms
      in_place.first.update!(status: "running")
    end

    it "is interim" do
      expect(report).to be_interim
    end
  end
end
