# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::IndexPage do
  subject(:page) { described_class.build }

  let(:experiment) { create(:experiment, name: "Mutation rate") }

  context "with no run" do
    it "lists the experiment with nothing done" do
      experiment

      expect(page.rows.sole).to have_attributes(runs_done: 0, runs_total: 0,
                                                transition_rate: have_attributes(fraction: nil))
    end
  end

  context "with runs that never transitioned" do
    it "reports a transition rate of zero" do
      create_list(:run, 2, experiment: experiment, status: "finished")

      expect(page.rows.sole).to have_attributes(runs_done: 2, runs_total: 2,
                                                transition_rate: have_attributes(fraction: 0.0))
    end
  end

  context "with a mix of finished and pending runs" do
    it "counts only finished runs in the rate" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 400)
      create(:run, experiment: experiment, status: "finished")
      create(:run, experiment: experiment)

      expect(page.rows.sole).to have_attributes(runs_done: 2, runs_total: 3,
                                                transition_rate: have_attributes(fraction: 0.5))
    end
  end

  it "orders experiments by name" do
    create(:experiment, name: "World size")
    experiment

    expect(page.rows.map { |row| row.experiment.name }).to eq(["Mutation rate", "World size"])
  end

  context "with no experiment" do
    it "has nothing to show" do
      expect(page).not_to be_any
    end
  end

  describe "#findings" do
    it "gives a row the registry findings resting on its sweep" do
      create(:experiment, name: "Neighbourhood radius", slug: "radius")

      expect(page.rows.sole.findings.map(&:slug)).to eq(["radius-locality"])
    end

    context "with a sweep no finding rests on" do
      it "leaves the row without one" do
        experiment

        expect(page.rows.sole.findings).to be_empty
      end
    end
  end

  describe "#planned" do
    it "lists the sweeps of the programme that have no experiment yet" do
      create(:experiment, name: "Mutation rate", slug: "mutation-rate")

      expect(page.planned.map(&:slug))
        .to eq(%w[mutation-rate-long world-size radius max-steps ops bff-control])
    end

    context "with a sweep built by hand under another slug" do
      it "excludes it by name rather than advertising it as unqueued" do
        create(:experiment, name: "BFF positive control", slug: "bff-control-rerun")

        expect(page.planned.map(&:slug)).not_to include("bff-control")
      end
    end

    it "describes each planned sweep from its programme entry" do
      expect(page.planned.first).to have_attributes(slug: "mutation-rate", name: "Mutation rate",
                                                    description: Lab::SWEEPS.fetch("mutation_rate")[:description])
    end
  end
end
