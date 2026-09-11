# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::HowItWorksPage do
  subject(:page) { described_class.build }

  describe "#sweeps" do
    it "keeps the declaration order of the programme and holds the control and the re-runs out of it" do
      expect(page.sweeps.map(&:name))
        .to eq(Lab::SWEEPS.except("bff_control", "mutation_rate_long").values.pluck(:name))
    end

    it "carries the question each sweep asks" do
      expect(page.sweeps.map(&:description)).to all(be_present)
    end

    it "names no experiment and no finding for a sweep the lab has not queued" do
      ablations = page.sweeps.find { |sweep| sweep.name == "Instruction set ablations" }

      expect(ablations).not_to be_experiment
      expect(ablations).not_to be_finding
    end

    context "with a queued sweep a finding cites" do
      it "carries both" do
        experiment = create(:experiment, name: "Mutation rate", slug: "mutation-rate")

        sweep = page.sweeps.first

        expect(sweep.experiment).to eq(experiment)
        expect(sweep.finding.slug).to eq("mutation-rate-window")
      end
    end

    context "with a sweep queued by hand under another slug" do
      it "recognises it by name" do
        experiment = create(:experiment, name: "Neighbourhood radius", slug: "radius-rerun")

        expect(page.sweeps.find { |sweep| sweep.name == "Neighbourhood radius" }.experiment).to eq(experiment)
      end
    end
  end

  describe "#follow_ups" do
    it "is the longer re-run of a sweep the programme already asked once" do
      expect(page.follow_ups.map(&:name)).to eq(["Mutation rate, long runs"])
    end

    it "carries the write-up that reads it" do
      expect(page.follow_ups.first.finding.slug).to eq("mutation-rate-long-horizon")
    end
  end

  describe "#control" do
    it "is the positive control, with the finding that states its falsifier" do
      expect(page.control.name).to eq("BFF positive control")
      expect(page.control.finding.slug).to eq("bff-control")
    end
  end
end
