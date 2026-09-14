# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::OpenEndednessSurvey do
  def sweep(key)
    create(:experiment, name: key.humanize, slug: Lab.slug_for(key),
                        param_grid: Lab::SWEEPS.fetch(key).fetch(:param_grid))
  end

  def transitioned_run(experiment, arm, lengths: [], lineages: [], transition_epoch: 100)
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch,
                       params: Lab::Schema.run_defaults.merge(arm))
    [lengths.size, lineages.size].max.times do |index|
      create(:sample, run: run, epoch: transition_epoch + (index * 10),
                      values: { "dominant_compressed_len" => lengths[index],
                                "distinct_lineages" => lineages[index] }.compact)
    end
    run
  end

  it "reads the three substrate sweeps of DESIGN 1.3 in order" do
    expect(described_class.build.bets.map(&:slug))
      .to eq(%w[energy-per-epoch environmental-structure max-tape-len])
  end

  it "decides the instruction-cost bet on lineages and the other two on complexity" do
    expect(described_class.build.bets.map(&:decided_by)).to eq(%i[lineages length length])
  end

  it "reads every sweep on both observables, deciding it on only one" do
    survey = described_class.build

    expect(survey.instruction_cost.decided_by).to eq(:lineages)
    expect(survey.instruction_cost_complexity).to have_attributes(decided_by: :length,
                                                                  slug: "energy-per-epoch")
    expect(survey.environmental_structure_lineages).to have_attributes(decided_by: :lineages,
                                                                       slug: "environmental-structure")
    expect(survey.room_to_grow_lineages).to have_attributes(decided_by: :lineages, slug: "max-tape-len")
  end

  it "takes the first arm of each grid as the control" do
    controls = described_class.build.bets.map { |bet| bet.control_arm.value }

    expect(controls).to eq([0, "uniform", 64])
  end

  context "with no run of the sweeps in the database" do
    it "resolves nothing and reads every hypothesis as unresolved" do
      survey = described_class.build

      expect(survey.any?).to be(false)
      expect(survey.bets.map(&:verdict)).to all(eq(:unresolved))
      expect(survey.transitioned_count).to eq(0)
    end
  end

  context "with a treated arm settling above its control" do
    it "reads the hypothesis as supported even while other arms are untestable" do
      experiment = sweep("max_tape_len")
      2.times { transitioned_run(experiment, { "max_tape_len" => 64 }, lengths: [36, 40]) }
      2.times { transitioned_run(experiment, { "max_tape_len" => 256 }, lengths: [60, 120]) }

      bet = described_class.build.bet("max-tape-len")

      expect(bet).to have_attributes(verdict: :supported, control_median_peak: 40, measured_count: 4)
      expect(bet.raising_arms.map(&:label)).to eq(["256"])
      expect(bet.untestable_arms.map(&:label)).to eq(%w[128 512])
    end
  end

  context "with every treated arm measured and plateauing where its control does" do
    it "reads the hypothesis as not supported" do
      experiment = sweep("environmental_structure")
      2.times { transitioned_run(experiment, { "structure" => "uniform" }, lengths: [36, 44]) }
      2.times { transitioned_run(experiment, { "structure" => "gradient" }, lengths: [36, 44]) }
      2.times { transitioned_run(experiment, { "structure" => "patchwork" }, lengths: [40, 40]) }

      bet = described_class.build.bet("environmental-structure")

      expect(bet).to have_attributes(verdict: :not_supported, refutable?: true)
      expect(bet.raising_arms).to be_empty
      expect(bet.untestable_arms).to be_empty
    end
  end

  context "with one treated arm under the threshold and no other arm raising the peak" do
    it "leaves the hypothesis unresolved and names the arm nothing could be read from" do
      experiment = sweep("max_tape_len")
      2.times { transitioned_run(experiment, { "max_tape_len" => 64 }, lengths: [36, 44]) }
      2.times { transitioned_run(experiment, { "max_tape_len" => 128 }, lengths: [30, 36]) }
      2.times { transitioned_run(experiment, { "max_tape_len" => 256 }, lengths: [30, 40]) }
      transitioned_run(experiment, { "max_tape_len" => 512 }, lengths: [30, 36])

      bet = described_class.build.bet("max-tape-len")

      expect(bet).to have_attributes(verdict: :unresolved, refutable?: false, control_comparable?: true)
      expect(bet.untestable_arms.map(&:label)).to eq(["512"])
    end
  end

  context "with half of an arm's runs above the control and half below" do
    it "needs more than half to read the arm as raising the peak" do
      experiment = sweep("environmental_structure")
      2.times { transitioned_run(experiment, { "structure" => "uniform" }, lengths: [36, 44]) }
      transitioned_run(experiment, { "structure" => "gradient" }, lengths: [60, 120])
      transitioned_run(experiment, { "structure" => "gradient" }, lengths: [30, 36])
      2.times { transitioned_run(experiment, { "structure" => "patchwork" }, lengths: [40, 40]) }

      bet = described_class.build.bet("environmental-structure")
      arm = bet.arms.find { |candidate| candidate.value == "gradient" }

      expect(arm.measured_count(:length)).to eq(2)
      expect(arm.above_count(:length, bet.control_median_peak)).to eq(1)
      expect(bet).to have_attributes(verdict: :not_supported, raising_arms: [])
    end
  end

  context "with a minority of an arm's runs above the control" do
    it "does not read that arm as raising the peak" do
      experiment = sweep("environmental_structure")
      2.times { transitioned_run(experiment, { "structure" => "uniform" }, lengths: [36, 44]) }
      transitioned_run(experiment, { "structure" => "gradient" }, lengths: [60, 120])
      2.times { transitioned_run(experiment, { "structure" => "gradient" }, lengths: [30, 36]) }
      2.times { transitioned_run(experiment, { "structure" => "patchwork" }, lengths: [40, 40]) }

      bet = described_class.build.bet("environmental-structure")
      arm = bet.arms.find { |candidate| candidate.value == "gradient" }

      expect(arm.above_count(:length, bet.control_median_peak)).to eq(1)
      expect(bet).to have_attributes(verdict: :not_supported, raising_arms: [])
    end
  end

  context "with a single run in the control arm" do
    it "leaves the hypothesis unresolved rather than deciding it on one seed" do
      experiment = sweep("max_tape_len")
      transitioned_run(experiment, { "max_tape_len" => 64 }, lengths: [36, 40])
      2.times { transitioned_run(experiment, { "max_tape_len" => 512 }, lengths: [60, 120]) }

      bet = described_class.build.bet("max-tape-len")

      expect(bet).to have_attributes(verdict: :unresolved, control_comparable?: false)
      expect(bet.control_arm.measured_count(:length)).to eq(1)
    end
  end

  context "with no treated arm transitioned" do
    it "leaves the hypothesis unresolved however many control runs there are" do
      experiment = sweep("max_tape_len")
      3.times { transitioned_run(experiment, { "max_tape_len" => 64 }, lengths: [36, 40]) }

      expect(described_class.build.bet("max-tape-len").verdict).to eq(:unresolved)
    end
  end

  it "counts a run as rising on its last reading against the middle of its own readings" do
    experiment = sweep("energy_per_epoch")
    transitioned_run(experiment, { "energy_per_epoch" => 0 }, lineages: [40, 90, 30])
    transitioned_run(experiment, { "energy_per_epoch" => 2**13 }, lineages: [40, 80])

    survey = described_class.build

    expect(survey.transitioned_count).to eq(2)
    expect(survey.measured_count(:lineages)).to eq(2)
    expect(survey.rising_count(:lineages)).to eq(1)
  end

  it "does not count a run that stepped up once right after its crossing" do
    experiment = sweep("energy_per_epoch")
    transitioned_run(experiment, { "energy_per_epoch" => 0 }, lineages: [10, 90, 12])

    expect(described_class.build.rising_count(:lineages)).to eq(0)
  end

  it "takes a run's peak from its highest reading after the crossing" do
    experiment = sweep("max_tape_len")
    transitioned_run(experiment, { "max_tape_len" => 128 }, lengths: [36, 90, 44])

    arm = described_class.build.bet("max-tape-len").arms.find { |candidate| candidate.value == 128 }

    expect(arm.peaks(:length)).to eq([90])
  end

  it "leaves out the samples taken before the crossing" do
    experiment = sweep("max_tape_len")
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: 200,
                       params: Lab::Schema.run_defaults.merge("max_tape_len" => 128))
    create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => 500 })
    create(:sample, run: run, epoch: 200, values: { "dominant_compressed_len" => 36 })

    arm = described_class.build.bet("max-tape-len").arms.find { |candidate| candidate.value == 128 }

    expect(arm.peaks(:length)).to eq([36])
  end

  it "keeps a run measured on one observable out of the other's counts" do
    experiment = sweep("environmental_structure")
    transitioned_run(experiment, { "structure" => "gradient" }, lengths: [36, 44])

    bet = described_class.build.bet("environmental-structure")

    expect(bet.measured_count_of(:length)).to eq(1)
    expect(bet.measured_count_of(:lineages)).to eq(0)
  end

  it "reads a null reading as no reading rather than as a zero" do
    experiment = sweep("max_tape_len")
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: 100,
                       params: Lab::Schema.run_defaults.merge("max_tape_len" => 128))
    create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => nil })

    expect(described_class.build.bet("max-tape-len").measured_count_of(:length)).to eq(0)
  end

  it "counts no run that has not transitioned" do
    experiment = sweep("max_tape_len")
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: nil,
                       params: Lab::Schema.run_defaults.merge("max_tape_len" => 128))
    create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => 44 })

    expect(described_class.build.transitioned_count).to eq(0)
  end

  it "badges each verdict" do
    expect(described_class::VERDICT_BADGES.keys).to eq(%i[supported not_supported unresolved])
    expect(described_class.build.bets.map(&:badge_class)).to all(eq("badge-info"))
  end
end
