# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::OutComputeReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { out_compute_experiment }
  let!(:parents) { out_compute_parents }
  let(:arms) do
    %i[out_compute equal shadow none].index_with { |treatment| out_compute_children(experiment, treatment) }
  end

  def test(hypothesis, tests = report.tests) = tests.find { |candidate| candidate.hypothesis == hypothesis }

  def outcomes(tests = report.tests) = tests.to_h { |candidate| [candidate.hypothesis, candidate.outcome] }

  # Samples every child of the four arms, each arm's options given by its key; an option
  # given as an array is read per child, in (parent, seed) order.
  def sample_arms(options = {})
    arms.each do |key, runs|
      runs.each_with_index { |run, index| out_compute_sample(run, **option_at(options.fetch(key, {}), index)) }
    end
  end

  def option_at(options, index) = options.transform_values { |value| value.is_a?(Array) ? value[index] : value }

  def child_of(run) = report.children.find { |child| child.run_id == run.id }

  before { Experiments::DescendantSweepBuilderService.call(experiment) }

  it "applies to the out-compute sweep alone" do
    expect([experiment, Experiment.find_by(slug: "reach-cap128")].map { |sweep| described_class.applies_to?(sweep) })
      .to eq([true, false])
  end

  it "starts one child per arm from the parent" do
    expect(report.arms.map(&:name)).to eq(%w[out-compute equal shadow none])
    expect(report.arms.map { |arm| arm.children.size }).to eq([1, 1, 1, 1])
    expect(report.children.map(&:parent_id).uniq).to eq(parents.map(&:id))
  end

  it "reads the three level tests and the two rise tests, each again with the extinct pairs kept and without " \
     "the piloted parents" do
    expect(report.tests.map { |candidate| [candidate.hypothesis, candidate.treatment.name, candidate.control.name] })
      .to eq([%w[H-endogenous out-compute none], %w[H-ratchet out-compute equal], %w[H-driven out-compute shadow],
              %w[H-rise-unassisted out-compute none], %w[H-repertoire out-compute none]])
    expect(report.readings.first.map(&:hypothesis))
      .to eq(["H-endogenous", "H-endogenous, extinct kept", "H-endogenous, unpiloted parents"])
  end

  context "with no child sampled yet" do
    it "is interim and every test reads no measured pairs" do
      expect(report).to be_interim
      expect(report.heading).to eq("out-compute reading, interim: not every child of every qualifying parent " \
                                   "has finished (Out-compute: imports a machine, not an objective)")
      expect([report.tests, report.kept_tests, report.unpiloted_tests].flatten.map(&:outcome)).to all(eq(:no_pairs))
    end
  end

  context "with the out-compute child deeper than every control and alone rising late" do
    before do
      sample_arms(out_compute: { fifth: 5, last: 6, classes_fifth: 12, classes_last: 14 },
                  equal: { fifth: 1 }, shadow: { fifth: 0 }, none: { fifth: 0 })
    end

    it "is final once every child has finished" do
      expect(report).not_to be_interim
      expect(report.to_text).to start_with("out-compute reading, final (Out-compute: imports a machine")
    end

    it "favours out-compute in every test, one pair too few for the sign test" do
      expect(outcomes.values).to all(eq(:not_shown))
      expect(report.tests.map { |candidate| candidate.comparison.favouring }).to all(eq(1))
    end

    it "counts each arm's children, their rises and the median last-decile depth" do
      expect(report.arms.map(&:cells)).to eq([["out-compute", 1, 1, 0, 0, 1, 1, 1, 0, 0, 6],
                                              ["equal", 1, 1, 0, 0, 1, 0, 0, 0, 0, 1],
                                              ["shadow", 1, 1, 0, 0, 1, 0, 0, 0, 0, 0],
                                              ["none", 1, 1, 0, 0, 1, 0, 0, 0, 0, 0]])
    end

    it "prints each child's depth and repertoire readings and its last-decile descriptive medians" do
      cells = child_of(arms[:out_compute].first).cells

      expect(Lab::OutComputeReading::CHILD_COLUMNS.zip(cells).to_h)
        .to include("fifth_decile_depth" => 5, "rise_bar" => 5, "last_decile_depth" => 6, "rises" => true,
                    "classes_bar" => 12, "last_decile_classes" => 14, "classes_rise" => true,
                    "repertoire_mean" => 2.5, "silent_share" => 0.1, "predation_rate" => 0.29,
                    "predation_relation_rate" => 0.32, "replicator_share" => 0.9)
    end
  end

  context "with five parents whose out-compute children alone are deep and rise" do
    let!(:parents) { out_compute_parents(count: 5) }

    before do
      sample_arms(out_compute: { fifth: 5, last: 6, classes_fifth: 12, classes_last: 14 },
                  equal: { fifth: 1 }, shadow: { fifth: 0 }, none: { fifth: 0 })
    end

    it "shows every test at p = 1/32, each carried by any one parent" do
      expect(outcomes.values).to all(eq(:held))
      expect(report.tests.map { |candidate| candidate.comparison.p_value }).to all(eq(Rational(1, 32)))
      expect(test("H-endogenous").comparison.carried_by).to match_array(parents.map { |parent| [parent.id] })
      expect(test("H-driven").outcome_label).to eq("shown")
    end

    it "leaves out no pair without the piloted parents, none of these being one" do
      expect(report.unpiloted_tests.map { |candidate| candidate.comparison.measured_count }).to all(eq(5))
    end

    context "with the first parent among the piloted ones" do
      before { stub_const("Lab::OutComputeReading::PILOT_PARENTS", [parents.first.id]) }

      it "re-reads every test without its pairs, which leaves four, too few to show, and decides nothing" do
        expect(outcomes.values).to all(eq(:held))
        expect(outcomes(report.unpiloted_tests).values).to all(eq(:not_shown))
        expect(report.unpiloted_tests.map { |candidate| candidate.comparison.measured_count }).to all(eq(4))
        expect(test("H-endogenous, unpiloted parents", report.unpiloted_tests).comparison.agreement.map(&:parent_id))
          .to eq(parents.drop(1).map(&:id))
      end
    end

    it "reads the per-parent agreement, one pair a parent" do
      expect(test("H-ratchet").comparison.agreement.map { |row| [row.parent_id, row.treatment, row.continuation] })
        .to eq(parents.map { |parent| [parent.id, 1, 0] })
    end
  end

  context "with the out-compute children deep but no deeper than the controls, and the none children alone " \
          "rising" do
    before do
      sample_arms(out_compute: { fifth: 5, classes_fifth: 12 }, equal: { fifth: 5 }, shadow: { fifth: 5 },
                  none: { fifth: 4, last: 5, classes_fifth: 1, classes_last: 2 })
    end

    it "refutes the level tests on ties and the rise tests on the control's rise" do
      expect(outcomes).to eq("H-endogenous" => :refuted, "H-ratchet" => :refuted, "H-driven" => :refuted,
                             "H-rise-unassisted" => :refuted, "H-repertoire" => :refuted)
      expect(test("H-ratchet").comparison).to have_attributes(favouring: 0, against: 0, ties: 1)
      expect(test("H-rise-unassisted").comparison).to have_attributes(favouring: 0, against: 1)
    end
  end

  context "with an out-compute child that held depth 6 at descent and re-climbs to it" do
    before do
      sample_arms(out_compute: { depth: ->(index) { index.zero? || index >= 190 ? 6 : 5 } }, none: { fifth: 0 })
    end

    it "reads its level above none's and no late rise, under the topless-rise bar" do
      expect(child_of(arms[:out_compute].first)).to have_attributes(level: 6, rises?: false)
      expect(outcomes.values_at("H-endogenous", "H-rise-unassisted")).to eq(%i[not_shown refuted])
    end
  end

  context "with a repertoire past the depth ceiling" do
    before { sample_arms(out_compute: { classes_fifth: 13, classes_last: 16 }) }

    it "reads the repertoire's rise with no ceiling, the depth's ceiling unchanged" do
      child = child_of(arms[:out_compute].first)

      expect(child.classes).to have_attributes(bar: 13, ceilinged?: false, rises?: true, reached_floor: false)
      expect(child).not_to be_ceilinged
    end
  end

  context "with an extinct none child" do
    before do
      sample_arms(out_compute: { fifth: 5, last: 6 }, none: { fifth: 0, share: 0.05 })
    end

    it "leaves its pair out of the none tests and keeps it in their extinct-kept reading" do
      expect(report.arms.last.cells).to eq(["none", 1, 1, 1, 1, 0, 0, 0, 0, 0, nil])
      expect(test("H-endogenous").comparison.measured_count).to eq(0)
      expect(test("H-ratchet").comparison.measured_count).to eq(1)
      expect(test("H-endogenous, extinct kept", report.kept_tests).comparison)
        .to have_attributes(measured_count: 1, favouring: 1)
    end
  end

  context "with a none child short of samples in its last decile" do
    before do
      sample_arms(out_compute: { fifth: 5, last: 6 },
                  none: { depth: ->(index) { index >= 190 ? nil : 0 } })
    end

    it "leaves the none pairs unmeasured" do
      expect(test("H-endogenous").comparison.agreement.sum(&:unmeasured)).to eq(1)
      expect(test("H-rise-unassisted").comparison.measured_count).to eq(0)
      expect(test("H-repertoire").comparison.measured_count).to eq(1)
    end
  end

  it "writes every table as CSV" do
    sample_arms
    expect(CSV.parse(report.to_csv)).to include(Lab::OutComputeReading::CHILD_COLUMNS,
                                                Lab::OutComputeReading::ARM_COLUMNS)
  end
end
