# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::IndexPage do
  subject(:page) { described_class.build }

  let(:experiment) { create(:experiment, name: "Mutation rate") }

  context "with no run" do
    it "lists the experiment with nothing done" do
      experiment

      expect(page.rows.sole).to have_attributes(runs_done: 0, runs_total: 0, transition_rate: nil)
    end
  end

  context "with runs that never transitioned" do
    it "reports a transition rate of zero" do
      create_list(:run, 2, experiment: experiment, status: "finished")

      expect(page.rows.sole).to have_attributes(runs_done: 2, runs_total: 2, transition_rate: 0.0)
    end
  end

  context "with a mix of finished and pending runs" do
    it "counts only finished runs in the rate" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 400)
      create(:run, experiment: experiment, status: "finished")
      create(:run, experiment: experiment)

      expect(page.rows.sole).to have_attributes(runs_done: 2, runs_total: 3, transition_rate: 0.5)
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
end
