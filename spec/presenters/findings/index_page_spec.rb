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

    it "rates a sweep over the same population its own page does" do
      experiment = create(:experiment, slug: "mutation-rate")
      create(:run, experiment: experiment, status: "finished", transition_epoch: 5_030)
      create(:run, experiment: experiment, status: "failed", transition_epoch: 6_000)
      create(:run, experiment: experiment, status: "running", transition_epoch: 7_000)

      row = page.rows.find { |candidate| candidate.finding.experiment_slug == "mutation-rate" }
      sweep = Experiments::ShowPage.build(experiment: experiment, paginate: ->(scope) { [nil, scope] })

      expect(row.transitioned).to eq(1)
      expect(row.transition_rate.fraction).to eq(sweep.transition_rate.fraction)
    end

    it "names the sweeps a transitioned run came from, in the order a reader scans them" do
      world_size = create(:experiment, name: "World size", slug: "world-size")
      radius = create(:experiment, name: "Radius", slug: "radius")
      create(:run, experiment: world_size, status: "failed", transition_epoch: 900)
      create(:run, experiment: radius, status: "finished", transition_epoch: 900)
      create(:run, experiment: create(:experiment), status: "running", transition_epoch: 900)

      expect(page.transitioned_sweeps.map(&:name)).to eq(["Radius", "World size"])
      expect(page.transitioned_runs_count).to eq(2)
    end

    it "reads everything the page asks it for in a fixed number of queries" do
      Findings::Registry.all.select(&:sweep?).each { |finding| create(:experiment, slug: finding.experiment_slug) }
      3.times { |seed| create(:run, seed: seed, status: "finished", transition_epoch: 900) }

      built = described_class.build

      expect(queries_during { built.rows }).to eq(3)
      expect(queries_during { built.transitioned_runs_count && built.transitioned_sweeps }).to eq(2)
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
