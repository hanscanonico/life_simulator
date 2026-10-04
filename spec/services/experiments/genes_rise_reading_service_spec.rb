# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::GenesRiseReadingService do
  subject(:report) { described_class.call(experiment: experiment, minima: minima) }

  let(:experiment) { genes_rise_experiment }
  let(:minima) { nil }
  let!(:parents) { genes_rise_parents }
  let(:arms) do
    %i[count capped shadow drift].index_with { |treatment| genes_rise_children(experiment, treatment) }
  end

  # Climbs to 20 by the fifth decile's end, then by one every 40 samples: 22 in the last
  # decile, new maxima into the final quarter, two above the bar where 1.2 times it is 24.
  let(:creep) { ->(index) { index < 105 ? 10 + (index / 10) : 20 + ((index - 105) / 40) } }
  # Climbs to 20, jumps to 30 at sample 120 and stands: its last maximum before the final
  # quarter.
  let(:jump) { ->(index) { index < 120 ? [10 + (index / 10), 20].min : 30 } }

  def test(hypothesis, tests = report.tests) = tests.find { |candidate| candidate.hypothesis == hypothesis }

  def outcomes(tests = report.tests) = tests.to_h { |candidate| [candidate.hypothesis, candidate.outcome] }

  # Samples every child of the four arms, each arm's options given by its key; an option
  # given as an array is read per child, in (parent, seed) order.
  def sample_arms(options = {})
    arms.each do |key, runs|
      runs.each_with_index { |run, index| genes_rise_sample(run, **option_at(options.fetch(key, {}), index)) }
    end
  end

  def option_at(options, index) = options.transform_values { |value| value.is_a?(Array) ? value[index] : value }

  def child_of(run) = report.children.find { |child| child.run_id == run.id }

  def count_child = child_of(arms[:count].first)

  # The count child climbing on both keys, the capped one creeping, shadow and drift flat at
  # one class.
  def climb_against_controls
    sample_arms(count: { classes: genes_rise_ramp }, capped: { classes: creep })
  end

  def minima_for(late:, flat:)
    arms[:count].to_h { |run| [run.id, Lab::GenesRiseReading::Minimum.new(fifth: late.first, last: late.last)] }
                .merge(arms[:drift].to_h do |run|
                  [run.id, Lab::GenesRiseReading::Minimum.new(fifth: flat.first, last: flat.last)]
                end)
  end

  before { Experiments::DescendantSweepBuilderService.call(experiment) }

  it "applies to the genes-rise sweep alone" do
    expect([experiment, Experiment.find_by(slug: "reach-cap128")].map { |sweep| described_class.applies_to?(sweep) })
      .to eq([true, false])
  end

  it "starts one child per arm from the parent past the ones the rule sets aside" do
    expect(report.arms.map(&:name)).to eq(%w[count capped shadow drift])
    expect(report.arms.map { |arm| arm.children.size }).to eq([1, 1, 1, 1])
    expect(report.children.map(&:parent_id).uniq).to eq(parents.map(&:id))
  end

  it "reads the five tests, each again with the extinct pairs kept" do
    expect(report.tests.map { |candidate| [candidate.hypothesis, candidate.treatment.name, candidate.control.name] })
      .to eq([%w[H-rise count drift], %w[H-rise-genes count drift], %w[H-room count capped],
              %w[H-shadow count shadow], %w[H-driven count drift]])
    expect(report.readings.first.map(&:hypothesis)).to eq(["H-rise", "H-rise, extinct kept"])
  end

  context "with no child sampled yet" do
    it "is interim, awaits the offline minimum, and every test reads no measured pairs" do
      expect(report).to be_interim
      expect(report.heading).to eq("genes-rise reading, interim: not every child of every qualifying parent " \
                                   "has finished; H-driven awaits the offline minimum " \
                                   "(Genes rise: imports a machine, not an objective)")
      expect([report.tests, report.kept_tests].flatten.map(&:outcome)).to all(eq(:no_pairs))
    end
  end

  context "with the count child alone climbing late" do
    before { climb_against_controls }

    it "is final once every child has finished" do
      expect(report).not_to be_interim
      expect(report.to_text).to start_with("genes-rise reading, final; H-driven awaits")
    end

    it "reads the count child's late rise on both keys: the rule, the maxima and the magnitude" do
      expect(count_child.classes).to have_attributes(bar: 20, last: 29, rises?: true, sustained?: true, large?: true,
                                                     late_rise?: true)
      expect(count_child.classes.maxima.size).to eq(19)
      expect(count_child.classes.last_maximum_epoch).to eq(arms[:count].first.parent_epoch + 19_100)
      expect(count_child.genes).to be_late_rise
    end

    it "favours count in the four live tests, one pair too few for the sign test, and reads no minimum" do
      expect(outcomes).to eq("H-rise" => :not_shown, "H-rise-genes" => :not_shown, "H-room" => :not_shown,
                             "H-shadow" => :not_shown, "H-driven" => :no_pairs)
    end

    it "counts each arm's children, their late rises and the median last-decile classes" do
      expect(report.arms.map(&:cells)).to eq([["count", 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 29],
                                              ["capped", 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 22],
                                              ["shadow", 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
                                              ["drift", 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]])
    end

    it "prints each child's two series, its final-quarter gain and its descriptive medians" do
      cells = Lab::GenesRiseReading::CHILD_COLUMNS.zip(count_child.cells).to_h

      expect(cells).to include("classes_descent" => 10, "classes_bar" => 20, "classes_last" => 29,
                               "classes_rises" => true, "classes_late_rise" => true, "genes_late_rise" => true,
                               "room_first" => 26, "room_last" => 28, "room_gain" => 2, "minimum_late_rise" => false,
                               "meta_len_mean" => 2_000.0, "near_cap" => false, "classes_per_kb_fifth" => 9.5,
                               "classes_per_kb" => 14.5,
                               "essential_genes_per_gene" => 0.464, "fidelity_p50" => 14,
                               "predation_relation_rate" => 0.33, "replicator_share" => 0.9)
    end
  end

  context "with five parents whose count children alone climb late" do
    let!(:parents) { genes_rise_parents(count: 5) }

    before { climb_against_controls }

    it "shows the four live tests at p = 1/32, each carried by any one parent" do
      expect(outcomes.except("H-driven").values).to all(eq(:held))
      expect(test("H-rise").comparison.p_value).to eq(Rational(1, 32))
      expect(test("H-room").comparison.carried_by).to match_array(parents.map { |parent| [parent.id] })
      expect(test("H-shadow").outcome_label).to eq("shown")
    end

    context "with the offline minimum rising in every count child and flat in drift" do
      let(:minima) { minima_for(late: [90, 150], flat: [1, 1]) }

      it "shows H-driven too" do
        expect(outcomes.fetch("H-driven")).to eq(:held)
        expect(report.heading).not_to include("awaits")
      end
    end

    context "with the offline minimum rising by less than a fifth" do
      let(:minima) { minima_for(late: [100, 110], flat: [1, 1]) }

      it "reads no late rise on it, and refutes H-driven on ties" do
        expect(count_child.minimum).to have_attributes(measured?: true, late_rise?: false)
        expect(test("H-driven").comparison).to have_attributes(favouring: 0, against: 0, ties: 5)
        expect(outcomes.fetch("H-driven")).to eq(:refuted)
      end
    end

    it "reads the per-parent agreement, one pair a parent" do
      expect(test("H-rise-genes").comparison.agreement.map { |row| [row.parent_id, row.treatment, row.continuation] })
        .to eq(parents.map { |parent| [parent.id, 1, 0] })
    end
  end

  context "with the count child creeping past its bar by less than a fifth" do
    before { sample_arms(count: { classes: creep }) }

    it "passes the rise rule and the maxima but not the magnitude, so reads no late rise" do
      expect(count_child.classes).to have_attributes(bar: 20, last: 22, rises?: true, sustained?: true, large?: false,
                                                     late_rise?: false)
      expect(outcomes.values_at("H-rise", "H-shadow")).to eq(%i[refuted refuted])
    end
  end

  context "with the count child jumping once and standing" do
    before { sample_arms(count: { classes: jump }) }

    it "clears the rule and the magnitude, but its last new maximum falls before the final quarter" do
      expect(count_child.classes).to have_attributes(bar: 20, last: 30, rises?: true, large?: true, sustained?: false,
                                                     late_rise?: false)
      expect(count_child.classes.last_maximum_epoch).to be < count_child.classes.final_quarter_epoch
    end
  end

  context "with a ramp that makes only two new maxima" do
    before { sample_arms(count: { classes: ->(index) { [20, 30, 31][(index >= 160 ? 1 : 0) + (index >= 180 ? 1 : 0)] } }) }

    it "reads no late rise: three are needed" do
      expect(count_child.classes).to have_attributes(rises?: true, large?: true, sustained?: false)
      expect(count_child.classes.maxima.size).to eq(2)
    end
  end

  context "with the drift child also climbing late" do
    before { sample_arms(count: { classes: genes_rise_ramp }, drift: { classes: genes_rise_ramp }) }

    it "ties H-rise and H-rise-genes, which reads refuted" do
      expect(outcomes.values_at("H-rise", "H-rise-genes")).to eq(%i[refuted refuted])
      expect(test("H-rise").comparison.ties).to eq(1)
    end
  end

  context "with the capped child gaining more over its final quarter than the count child" do
    before do
      sample_arms(count: { classes: ->(index) { index < 152 ? 10 + (index / 10) : 25 } },
                  capped: { classes: ->(index) { index < 176 ? 20 : 30 } })
    end

    it "favours capped in H-room, pair by pair, which reads refuted" do
      expect([count_child.room.gain, child_of(arms[:capped].first).room.gain]).to eq([0, 10])
      expect(test("H-room").comparison).to have_attributes(favouring: 0, against: 1)
      expect(outcomes.fetch("H-room")).to eq(:refuted)
    end
  end

  context "with equal final-quarter gains" do
    before { sample_arms(count: { classes: genes_rise_ramp }, capped: { classes: genes_rise_ramp }) }

    it "ties the H-room pair" do
      expect(test("H-room").comparison).to have_attributes(favouring: 0, against: 0, ties: 1)
    end
  end

  context "with an extinct drift child" do
    before { sample_arms(count: { classes: genes_rise_ramp }, drift: { share: 0.05 }) }

    it "leaves its pair out of the drift tests and keeps it in their extinct-kept reading" do
      expect(report.arms.last.cells).to eq(["drift", 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, nil])
      expect(test("H-rise").comparison.measured_count).to eq(0)
      expect(test("H-shadow").comparison.measured_count).to eq(1)
      expect(test("H-rise, extinct kept", report.kept_tests).comparison)
        .to have_attributes(measured_count: 1, favouring: 1)
    end
  end

  context "with a capped child short of samples in its final quarter" do
    before do
      sample_arms(count: { classes: genes_rise_ramp }, capped: { classes: ->(index) { index >= 152 ? nil : 1 } })
    end

    it "leaves the H-room pair unmeasured" do
      expect(test("H-room").comparison.agreement.sum(&:unmeasured)).to eq(1)
    end
  end

  context "with a count child near its cap" do
    before { sample_arms(count: { classes: genes_rise_ramp, length: 3_700.0 }) }

    it "counts it near the cap, which decides nothing" do
      expect(count_child).to be_near_cap
      expect(report.arms.first.cells[10]).to eq(1)
      expect(outcomes.fetch("H-rise")).to eq(:not_shown)
    end
  end

  it "writes every table as CSV" do
    sample_arms
    expect(CSV.parse(report.to_csv)).to include(Lab::GenesRiseReading::CHILD_COLUMNS,
                                                Lab::GenesRiseReading::ARM_COLUMNS)
  end
end
