# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:reach_cap128_report" do
  let!(:experiment) { reach_cap128_experiment }

  before do
    reach_run(experiment, crossing: 1_000, shares: [0.0, 0.9, 0.9], seed: 7)
    reach_run(experiment, status: "pending", seed: 8)
    control_run(host_parasite_control_experiment, seed: 7)
  end

  after { ENV.delete("FORMAT") }

  it "prints every run under its arm, labelled interim while runs are pending" do
    expect(invoke("lab:reach_cap128_report"))
      .to start_with("interim reading")
      .and match(/^\s*arm\s+seed\s+run_id\s+status\s+emergence_epoch\s+measured\s+emerged/)
      .and match(/radius 4\s+7\s+\d+\s+finished\s+1000\s+true\s+true/)
      .and match(/radius 4\s+8\s+\d+\s+pending\s+—\s+true\s+—/)
  end

  it "prints the arm table and the hypothesis" do
    expect(invoke("lab:reach_cap128_report"))
      .to match(/control, radius 1\s+1\s+1\s+1\s+0/)
      .and include("H-reach128 not shown; radius 4 1/1 against control, radius 1 0/1")
  end

  context "with FORMAT=csv" do
    it "writes CSV" do
      ENV["FORMAT"] = "csv"

      expect(CSV.parse(invoke("lab:reach_cap128_report")))
        .to include(Lab::ReachCap128Reading::RUN_COLUMNS, Lab::ReachCap128Reading::ARM_COLUMNS)
    end
  end

  context "with no reach-cap128 sweep seeded" do
    it "says so" do
      experiment.update!(slug: "another-sweep")

      expect { invoke("lab:reach_cap128_report") }.to raise_error(/not seeded/)
    end
  end

  def invoke(name, *args)
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task[name]
    task.reenable
    original = $stdout
    $stdout = StringIO.new
    task.invoke(*args)
    $stdout.string
  ensure
    $stdout = original
  end
end
