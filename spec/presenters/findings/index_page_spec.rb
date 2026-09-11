# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::IndexPage do
  subject(:page) { described_class.build }

  def queries_during(&reading)
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &reading)
    queries
  end

  it "lists every published finding" do
    expect(page.rows.map { |row| row.finding.slug }).to eq(Findings::Registry.all.map(&:slug))
  end

  it "has something to show" do
    expect(page).to be_any
  end

  context "with the sweep in the lab" do
    it "resolves the experiment behind the finding" do
      experiment = create(:experiment, slug: "mutation-rate")

      row = page.rows.find { |candidate| candidate.finding.experiment_slug == "mutation-rate" }

      expect(row.experiment).to eq(experiment)
    end

    it "counts the sweep's finished and transitioned runs" do
      experiment = create(:experiment, slug: "mutation-rate")
      create(:run, experiment: experiment, status: "finished", transition_epoch: 5_030)
      create(:run, experiment: experiment, status: "finished", transition_epoch: nil)
      create(:run, experiment: experiment, status: "pending")

      row = page.rows.find { |candidate| candidate.finding.experiment_slug == "mutation-rate" }

      expect(row).to have_attributes(runs_done: 2, runs_total: 3, transitioned: 1)
      expect(row.transition_rate.fraction).to eq(0.5)
    end

    it "reads the whole log in a fixed number of queries" do
      Findings::Registry.all.to_a.each { |finding| create(:experiment, slug: finding.experiment_slug) }

      expect(queries_during { described_class.build.rows }).to eq(3)
    end
  end

  context "with the sweep missing" do
    it "keeps the row without an experiment" do
      expect(page.rows.map(&:experiment?)).to all(be(false))
    end

    it "counts no run for it" do
      expect(page.rows.map(&:runs_done)).to all(eq(0))
      expect(page.rows.map(&:transitioned)).to all(eq(0))
    end
  end
end
