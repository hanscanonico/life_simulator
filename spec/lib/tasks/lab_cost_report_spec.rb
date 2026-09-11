# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:cost_report" do
  let(:experiment) { create(:experiment, slug: "world-size", param_grid: { "width" => [32, 128] }) }

  before do
    create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, compute_seconds: 400.0,
                 params: Lab::Schema.run_defaults.merge("width" => 32))
    create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, compute_seconds: 200.0,
                 params: Lab::Schema.run_defaults.merge("width" => 32))
    create(:run, experiment: experiment, status: "running", epochs_done: 10_000, compute_seconds: 3_600.0,
                 params: Lab::Schema.run_defaults.merge("width" => 128))
  end

  it "prints the arm header" do
    expect(invoke("lab:cost_report", "world-size"))
      .to match(/arm\s+n\s+mean_epochs_per_compute_s\s+min\s+max\s+compute_hours/)
  end

  it "reads mean, min and max epochs per compute second off the arm's runs" do
    expect(invoke("lab:cost_report", "world-size")).to match(/^\s*32\s+2\s+75\s+50\s+100\s+0\.167$/)
  end

  it "totals the compute the experiment has burned" do
    expect(invoke("lab:cost_report", "world-size")).to include("3 runs with compute recorded, 1.17 compute hours")
  end

  context "with a run no runner has charged compute to" do
    it "leaves it out rather than dividing by nothing" do
      create(:run, experiment: experiment, status: "pending",
                   params: Lab::Schema.run_defaults.merge("width" => 32))

      expect(invoke("lab:cost_report", "world-size")).to include("3 runs with compute recorded")
    end
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:cost_report", "colour") }.to raise_error(/Unknown experiment "colour"/)
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
