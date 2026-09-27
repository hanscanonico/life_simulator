# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::LocalityEmergenceReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { locality_emergence_experiment }

  def arm(radius) = report.arms.find { |candidate| candidate.radius == radius }

  def emerged(run) = report.rows.find { |row| row.run_id == run.id }.emerged

  it "applies to the locality-emergence sweep alone" do
    expect([described_class.applies_to?(experiment), described_class.applies_to?(create(:experiment))])
      .to eq([true, false])
  end

  describe "the emergence predicate" do
    it "counts a crossing followed by a share of at least one half" do
      expect(emerged(locality_run(experiment, radius: 4, share: 0.5))).to be(true)
    end

    it "does not count a crossing whose share stays below one half" do
      expect(emerged(locality_run(experiment, radius: 4, share: 0.49))).to be(false)
    end

    it "does not count a run with no crossing" do
      expect(emerged(locality_run(experiment, radius: 4))).to be(false)
    end

    context "with the share read before the crossing" do
      it "does not count it" do
        run = locality_run(experiment, radius: 4, share: 0.1)
        create(:sample, run: run, epoch: 999, values: { "replicator_share" => 0.9 })

        expect(emerged(run)).to be(false)
      end
    end

    context "with a share that is not a number" do
      it "reads it as no reading" do
        run = locality_run(experiment, radius: 4, share: 0.1)
        create(:sample, run: run, epoch: 1_010, values: { "replicator_share" => "0.9" })

        expect(emerged(run)).to be(false)
      end
    end
  end

  context "with every run finished" do
    before do
      locality_run(experiment, radius: 0, share: 0.9)
      locality_run(experiment, radius: 4, share: 0.9)
      locality_run(experiment, radius: 4)
      locality_run(experiment, radius: 1, share: 0.2)
    end

    it "is final" do
      expect(report).not_to be_interim
    end

    it "lists the arms by reach, well-mixed last" do
      expect(report.arms.map(&:label)).to eq(["radius 1", "radius 4", "well-mixed"])
    end

    it "counts each arm's finished and emerged runs" do
      expect(arm(4).cells).to eq(["radius 4", 2, 2, 1, 0.5])
      expect(arm(1).cells).to eq(["radius 1", 1, 1, 0, 0.0])
    end

    it "reads both hypotheses" do
      expect(report.peak.outcome).to eq(:not_shown)
      expect(report.shape.outcome).to eq(:untested)
    end
  end

  context "with a run still under way" do
    before do
      locality_run(experiment, radius: 4, share: 0.9)
      locality_run(experiment, radius: 4, share: 0.9, status: "running")
    end

    it "is interim, and does not count the running run" do
      expect(report).to be_interim
      expect(arm(4).cells).to eq(["radius 4", 2, 1, 1, 1.0])
    end
  end
end
