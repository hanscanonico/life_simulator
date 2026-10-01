# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ReachCap128ReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { reach_cap128_experiment }
  let(:control) { host_parasite_control_experiment }

  def row(run) = report.rows.find { |candidate| candidate.run_id == run.id }

  def emerged(run) = row(run).emerged

  it "applies to the reach-cap128 sweep alone" do
    expect([described_class.applies_to?(experiment), described_class.applies_to?(create(:experiment))])
      .to eq([true, false])
  end

  describe "the stored-reading emergence predicate" do
    it "counts a crossing followed by a stored world at a share of at least one half" do
      expect(emerged(reach_run(experiment, crossing: 1_000, shares: [0.0, 0.5, 0.2]))).to be(true)
    end

    it "does not count a crossing whose stored worlds stay below one half" do
      expect(emerged(reach_run(experiment, crossing: 1_000, shares: [0.0, 0.49, 0.3]))).to be(false)
    end

    it "does not count a run with no crossing" do
      expect(emerged(reach_run(experiment, shares: [0.0, 0.9, 0.9]))).to be(false)
    end

    context "with the share held only before the crossing" do
      it "does not count it" do
        expect(emerged(reach_run(experiment, crossing: 1_500, shares: [0.0, 0.9, 0.1]))).to be(false)
      end
    end

    context "with a live sample at the share but no stored world at it" do
      it "does not count it" do
        run = reach_run(experiment, crossing: 1_000, shares: [0.0, 0.1, 0.1])
        create(:sample, run: run, epoch: 1_500, values: { "replicator_share" => 0.9 })

        expect(emerged(run)).to be(false)
      end
    end

    context "with a world the readings pass has not read" do
      it "leaves the run uncounted" do
        run = reach_run(experiment, crossing: 1_000, shares: [0.0, 0.9, 0.9], unread: true)

        expect([emerged(run), row(run).measured]).to eq([nil, false])
      end
    end

    context "with a reading stepped past the stored world" do
      it "does not count it" do
        run = reach_run(experiment, crossing: 1_000, shares: [0.0, 0.1, 0.1])
        create(:snapshot_reading, run: run, epoch: 1_010, source_epoch: 1_000, values: { "replicator_share" => 0.9 })

        expect(emerged(run)).to be(false)
      end
    end
  end

  describe "the control arm" do
    it "reads the host-parasite sweep's economy-off cap-128 founding runs alone" do
      kept = control_run(control)
      control_run(control, params: { "radius" => 1, "max_tape_len" => 256 })
      control_run(control, params: { "radius" => 1, "energy_influx" => 2**11, "steal_amount" => 2**10 })
      create(:run, :descendant, experiment: control, params: kept.params)

      expect(report.arms.last.rows.map(&:run_id)).to eq([kept.id])
    end
  end

  context "with every run of both arms finished and read" do
    before do
      reach_run(experiment, crossing: 1_000, shares: [0.0, 0.9, 0.8])
      reach_run(experiment, crossing: 1_000, shares: [0.0, 0.6, 0.4])
      reach_run(experiment)
      control_run(control, crossing: 1_000, shares: [0.0, 0.7, 0.7])
      control_run(control)
      control_run(control)
    end

    it "is final" do
      expect(report).not_to be_interim
      expect(report.heading).to eq("final reading")
    end

    it "lists radius 4 first and the control after it" do
      expect(report.arms.map(&:label)).to eq(["radius 4", "control, radius 1"])
    end

    it "counts each arm's runs and reads the comparison" do
      expect(report.arms.map { |arm| [arm.counted, arm.emerged] }).to eq([[3, 2], [3, 1]])
      expect(report.comparison.outcome).to eq(:not_shown)
    end

    it "reads the terminal share and the eligible parents" do
      expect(report.arms.first.median_terminal_share).to eq(0.4)
      expect(report.arms.first.eligible_parents).to eq(1)
    end
  end

  context "with the dominant tape at the last live sample" do
    it "reads its raw length and instruction count on emerged runs" do
      run = reach_run(experiment, crossing: 1_000, shares: [0.0, 0.9, 0.9])
      create(:sample, run: run, epoch: 1_990, values: { "dominant_raw_len" => 100, "dominant_instruction_count" => 9 })
      create(:sample, run: run, epoch: 2_000, values: { "dominant_raw_len" => 128, "dominant_instruction_count" => 17 })

      expect([row(run).dominant_raw_len, row(run).dominant_instruction_count, row(run).dominant_self_replicates])
        .to eq([128, 17, true])
    end
  end

  context "with a run still under way" do
    before do
      reach_run(experiment, crossing: 1_000, shares: [0.0, 0.9, 0.9])
      reach_run(experiment, status: "running")
      control_run(control)
    end

    it "is interim, and does not count the running run" do
      expect(report).to be_interim
      expect(report.arms.first.cells.first(5)).to eq(["radius 4", 2, 1, 1, 1])
    end
  end

  context "with every run finished but a world still unread" do
    before do
      reach_run(experiment, crossing: 1_000, shares: [0.0, 0.9, 0.9], unread: true)
      control_run(control)
    end

    it "is interim" do
      expect(report).to be_interim
    end
  end

  context "with no host-parasite sweep" do
    it "reads an empty control and leaves the hypothesis untested" do
      reach_run(experiment)

      expect([report.arms.last.rows, report.comparison.outcome, report.interim?]).to eq([[], :untested, true])
    end
  end
end
