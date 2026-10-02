# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ToplessRiseReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { topless_rise_experiment }
  let!(:parents) { topless_rise_parents }
  let(:rise) { topless_rise_children(experiment, :rise) }
  let(:capped) { topless_rise_children(experiment, :capped) }
  let(:none) { topless_rise_children(experiment, :none) }

  def test(hypothesis, tests = report.tests) = tests.find { |candidate| candidate.hypothesis == hypothesis }

  def outcomes(tests = report.tests) = tests.to_h { |candidate| [candidate.hypothesis, candidate.outcome] }

  # Samples every child of the three arms, each arm's options given by its key; an option
  # given as an array is read per child, in (parent, seed) order.
  def sample_arms(arms = {})
    { rise: rise, capped: capped, none: none }.each do |key, runs|
      runs.each_with_index { |run, index| topless_rise_sample(run, **option_at(arms.fetch(key, {}), index)) }
    end
  end

  def option_at(options, index) = options.transform_values { |value| value.is_a?(Array) ? value[index] : value }

  before { Experiments::DescendantSweepBuilderService.call(experiment) }

  it "applies to the topless-rise sweep alone" do
    expect([experiment, Experiment.find_by(slug: "meta-stack")].map { |sweep| described_class.applies_to?(sweep) })
      .to eq([true, false])
  end

  it "starts one child per arm from each of the three meta-stack-arm children" do
    expect(parents.size).to eq(3)
    expect(report.arms.map(&:name)).to eq(%w[rise capped none])
    expect(report.arms.map { |arm| arm.children.size }).to eq([3, 3, 3])
    expect(report.children.map(&:parent_id).uniq).to match_array(parents.map(&:id))
  end

  it "reads H-rise against none and H-rise-paid against capped, each again with the extinct pairs kept and on " \
     "the deep parents" do
    expect(report.tests.map { |candidate| [candidate.hypothesis, candidate.treatment.name, candidate.control.name] })
      .to eq([%w[H-rise rise none], %w[H-rise-paid rise capped]])
    expect(report.readings.map { |readings| readings.map(&:hypothesis) }.first)
      .to eq(["H-rise", "H-rise, extinct kept", "H-rise, deep subgroup"])
  end

  context "with no child sampled yet" do
    it "is interim and every test reads no measured pairs" do
      expect(report).to be_interim
      expect(report.heading).to eq("topless-rise reading, interim: not every child of every qualifying parent " \
                                   "has finished (#{Lab::ToplessRiseReading::LABEL})")
      expect([report.tests, report.kept_tests, report.deep_tests].flatten.map(&:outcome)).to all(eq(:no_pairs))
    end
  end

  context "with every rise child rising late and neither control" do
    before { sample_arms(rise: { fifth: 9, last: 10 }, capped: { fifth: 9 }, none: { fifth: 5, last: 4 }) }

    it "is final once every child has finished" do
      expect(report).not_to be_interim
      expect(report.to_text).to start_with("topless-rise reading, final (Topless rise: imports an objective")
    end

    it "favours the rise arm in every pair, too few for the sign test" do
      expect(outcomes).to eq("H-rise" => :not_shown, "H-rise-paid" => :not_shown)
      expect(test("H-rise").comparison).to have_attributes(favouring: 3, against: 0, ties: 0)
    end

    it "counts the rises per arm" do
      expect(report.arms.map(&:cells)).to eq([["rise", 3, 3, 0, 0, 3, 3, 0, 0], ["capped", 3, 3, 0, 0, 3, 0, 0, 0],
                                              ["none", 3, 3, 0, 0, 3, 0, 0, 0]])
    end
  end

  context "with the controls rising as often as the rise arm" do
    before { sample_arms(rise: { fifth: 9, last: 10 }, capped: { fifth: 6, last: 8 }, none: { fifth: [3, 9, 9] }) }

    it "refutes H-rise-paid and leaves H-rise not shown" do
      expect(outcomes).to eq("H-rise" => :not_shown, "H-rise-paid" => :refuted)
      expect(test("H-rise-paid").comparison).to have_attributes(favouring: 0, against: 0, ties: 3)
    end
  end

  context "with six parents whose rise children alone rise" do
    let!(:parents) { topless_rise_parents(count: 2) }

    before { sample_arms(rise: { fifth: 8, last: 9 }, capped: { fifth: 8 }, none: { fifth: 8 }) }

    it "shows both tests at p = 1/64, each carried by every two parents" do
      expect(outcomes).to eq("H-rise" => :held, "H-rise-paid" => :held)
      expect(test("H-rise").comparison.p_value).to eq(Rational(1, 64))
      expect(test("H-rise").comparison.carried_by.size).to eq(15)
      expect(test("H-rise").outcome_label).to eq("shown")
    end

    it "reads the per-parent agreement, one pair a parent" do
      expect(test("H-rise").comparison.agreement.map(&:treatment)).to eq([1, 1, 1, 1, 1, 1])
    end

    context "with two of those parents in the deep subgroup" do
      before { stub_const("Lab::ToplessRiseReading::DEEP_PARENTS", parents.first(2).map(&:id)) }

      it "re-reads every test on their children alone" do
        expect(outcomes(report.deep_tests)).to eq("H-rise, deep subgroup" => :not_shown,
                                                  "H-rise-paid, deep subgroup" => :not_shown)
        expect(test("H-rise, deep subgroup", report.deep_tests).comparison.measured_count).to eq(2)
        expect(report.children.select(&:deep_parent?).map(&:parent_id).uniq).to match_array(parents.first(2).map(&:id))
      end
    end
  end

  context "with a rise child already at the ceiling by its fifth decile" do
    before do
      sample_arms(rise: { fifth: [13, 9, 9], last: [13, 9, 9] }, none: { fifth: 2, last: 3 })
    end

    it "reads it as no rise, counts it apart and prints it apart" do
      ceilinged = rise.first
      expect(report.ceilinged.map(&:run_id)).to eq([ceilinged.id])
      expect(report.arms.first.cells).to eq(["rise", 3, 3, 0, 0, 3, 0, 1, 1])
      expect(test("H-rise").comparison).to have_attributes(favouring: 0, against: 3)
      expect(outcomes["H-rise"]).to eq(:refuted)
      expect(report.to_text.scan(/^\s*#{ceilinged.id}\s/).size).to eq(2)
      expect(report).not_to be_mostly_ceilinged
    end
  end

  context "with two of the three rise children at the ceiling" do
    before { sample_arms(rise: { fifth: [13, 13, 9], last: [13, 13, 10] }) }

    it "reads the ladder as having a near top" do
      expect(report).to be_mostly_ceilinged
      expect(report.heading).to include("final; most rise children ceilinged, the tests are not an answer")
    end
  end

  context "with the rise children climbing back only to the parent's depth at descent" do
    before do
      sample_arms(rise: { depth: ->(index) { index.zero? || index >= 190 ? 5 : 3 } }, capped: { fifth: 3 },
                  none: { fifth: 3 })
    end

    it "reads no rise in any pair" do
      expect(report.arms.first.cells).to eq(["rise", 3, 3, 0, 0, 3, 0, 0, 0])
      expect(test("H-rise").comparison).to have_attributes(favouring: 0, against: 0, ties: 3)
    end
  end

  context "with a none child that held nothing at its fifth decile and ECHO at its last" do
    before { sample_arms(rise: { fifth: 9 }, capped: { fifth: 9 }, none: { fifth: -1, last: [0, -1, -1] }) }

    it "reads −1 as one below ECHO, so that child, which held nothing at descent either, rises and the others do not" do
      expect(none.map { |run| report.children.find { |child| child.run_id == run.id }.rises? }).to eq([true, false, false])
      expect(test("H-rise").comparison).to have_attributes(favouring: 0, against: 1, ties: 2)
    end
  end

  context "with an extinct none child" do
    before { sample_arms(rise: { fifth: 9, last: 10 }, capped: { fifth: 9 }, none: { fifth: 9, share: [0.05, 0.9, 0.9] }) }

    it "leaves its pair out of the test and keeps it in the extinct-kept reading" do
      expect(report.arms.last.cells).to eq(["none", 3, 3, 1, 1, 2, 0, 0, 0])
      expect(test("H-rise").comparison.measured_count).to eq(2)
      expect(test("H-rise, extinct kept", report.kept_tests).comparison.measured_count).to eq(3)
    end
  end

  context "with a child short of samples in its fifth decile" do
    before do
      sample_arms(rise: { fifth: 9, last: 10 }, capped: { fifth: 9 },
                  none: { depth: [->(index) { index.between?(140, 149) ? nil : 4 }, nil, nil] })
    end

    it "leaves the pair unmeasured" do
      expect(test("H-rise").comparison.measured_count).to eq(2)
      expect(test("H-rise").comparison.agreement.sum(&:unmeasured)).to eq(1)
    end
  end

  it "writes every table as CSV" do
    sample_arms
    expect(CSV.parse(report.to_csv)).to include(Lab::ToplessRiseReading::CHILD_COLUMNS,
                                                Lab::ToplessRiseReading::ARM_COLUMNS)
  end
end
