# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::LineageDiversityReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { lineage_diversity_experiment }

  def arm(radius) = report.arms.find { |candidate| candidate.radius == radius }

  it "applies to the lineage-diversity sweep alone" do
    expect([described_class.applies_to?(experiment), described_class.applies_to?(create(:experiment))])
      .to eq([true, false])
  end

  context "with every run finished" do
    before do
      [5.0, 4.0, 1.7].each { |effective| lineage_run(experiment, radius: 1, effective: effective) }
      [1.0, 3.0].each { |effective| lineage_run(experiment, radius: 0, effective: effective) }
      lineage_run(experiment, radius: 2, effective: 1.0)
      lineage_run(experiment, radius: 4, effective: 1.0, share: 0.4)
    end

    it "is final" do
      expect(report).not_to be_interim
    end

    it "lists the arms well-mixed first" do
      expect(report.arms.map(&:label)).to eq(["well-mixed", "radius 4", "radius 2", "radius 1"])
    end

    it "counts each arm's runs by class" do
      expect(arm(1).cells.first(11)).to eq(["radius 1", 3, 3, 3, 3, 2, 1, 0, 0, 4.0, "read"])
      expect(arm(0).cells.first(11)).to eq(["well-mixed", 2, 2, 2, 2, 1, 0, 1, 0, 1.0, "read"])
    end

    it "leaves an arm with too few measured runs unread" do
      expect(arm(2).read?).to be(false)
    end

    it "counts a run under the share threshold as not emerged" do
      expect(arm(4).cells[3]).to eq(0)
    end

    it "tests the trend over the read arms alone" do
      expect(report.hypothesis).to have_attributes(testable?: true, statistic: 5)
      expect(report.hypothesis.read_arms.map(&:radius)).to eq([0, 1])
    end

    it "deals the same p on every call" do
      expect(report.hypothesis.p_value).to eq(described_class.call(experiment: experiment).hypothesis.p_value)
    end

    it "reads the descriptive observables over the same last decile" do
      expect(arm(1).descriptive("lineages_over_one_percent")).to eq(2)
    end
  end

  context "with a run still under way" do
    before do
      lineage_run(experiment, radius: 1, effective: 3.0)
      lineage_run(experiment, radius: 1, effective: 3.0, status: "running")
    end

    it "is interim, and does not read the running run" do
      expect(report).to be_interim
      expect(arm(1).cells.first(5)).to eq(["radius 1", 2, 1, 1, 1])
      expect(report.rows.map(&:reading).compact.size).to eq(1)
    end
  end

  context "with a failed run" do
    before do
      lineage_run(experiment, radius: 1, effective: 3.0)
      lineage_run(experiment, radius: 1, effective: 3.0, status: "failed")
    end

    it "is interim" do
      expect(report).to be_interim
    end
  end

  context "with samples before the emergence epoch" do
    before do
      run = lineage_run(experiment, radius: 1, effective: 1.0)
      50.times do |index|
        create(:sample, run: run, epoch: index * 10,
                        values: { "replicator_share" => 0.9, "lineage_effective_count" => 9.0 })
      end
    end

    it "reads from the emergence epoch on" do
      expect(report.rows.first.reading).to have_attributes(verdict: :monophyletic, decile_readings: 10)
    end
  end

  context "with the radius sweep on record" do
    before do
      radius = create(:experiment, slug: "radius")
      create(:run, :emerged, experiment: radius, params: Lab::Schema.run_defaults.merge("radius" => 1))
      create(:run, experiment: radius, status: "finished", params: Lab::Schema.run_defaults.merge("radius" => 1))
      lineage_run(experiment, radius: 1, effective: 3.0)
    end

    it "sets each arm's emergence count beside the radius sweep's" do
      expect(arm(1)).to have_attributes(radius_emerged: 1, radius_finished: 2)
    end
  end

  context "with the trend's p already dealt" do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(Rails).to receive(:cache).and_return(store)
      [3.0, 4.0].each { |effective| lineage_run(experiment, radius: 1, effective: effective) }
      [1.0, 1.0].each { |effective| lineage_run(experiment, radius: 0, effective: effective) }
      described_class.call(experiment: experiment)
    end

    it "reads it from the cache rather than dealing again" do
      allow(Stats::JonckheereTerpstra).to receive(:new).and_call_original
      described_class.call(experiment: experiment).hypothesis.p_value

      expect(Stats::JonckheereTerpstra).not_to have_received(:new)
    end
  end
end
