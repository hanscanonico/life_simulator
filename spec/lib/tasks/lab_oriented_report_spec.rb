# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:oriented_report" do
  let(:experiment) { create(:experiment, slug: "radius", param_grid: { "radius" => [1, 2] }) }

  before do
    run = create(:run, experiment: experiment, status: "finished", epochs: 2_000, transition_epoch: 500,
                       params: Lab::Schema.run_defaults.merge("radius" => 2))
    create(:snapshot_reading, run: run, epoch: 2_000, source_epoch: 2_000, values: { "replicator_share" => 0.8 })
    other = create(:experiment, slug: "cap")
    create(:run, experiment: other, status: "finished", emergence_epoch: 100, emergence_witness: "census")
  end

  it "prints the experiment's arm table" do
    expect(invoke("lab:oriented_report", "radius")).to match(/^\s*2\s+1\s+1\s+1\s+0\s+1\s+1\s+1\s+0\s+2000$/)
  end

  context "with FORMAT=csv" do
    it "writes the arm table as CSV" do
      csv = with_env("FORMAT", "csv") { invoke("lab:oriented_report", "radius") }

      expect(CSV.parse(csv)).to eq([Experiments::OrientedArmsService::COLUMNS, %w[2 1 1 1 0 1 1 1 0 2000],
                                    %w[all 1 1 1 0 1 1 1 0 2000]])
    end
  end

  context "with all" do
    it "prints every experiment's totals and the corpus total" do
      text = invoke("lab:oriented_report", "all")

      expect(text).to match(/^\s*radius\s+1\s+1\s+1\s+0\s+1\s+1\s+1\s+0\s+2000$/)
      expect(text).to match(/^\s*cap\s+1\s+0\s+0\s+1\s+0\s+0\s+0\s+0\s+—$/)
      expect(text).to match(/^\s*all\s+2\s+1\s+1\s+1\s+1\s+1\s+1\s+0\s+2000$/)
    end
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:oriented_report", "colour") }.to raise_error(/Unknown experiment "colour"/)
  end

  def with_env(name, value)
    original = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = original
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
