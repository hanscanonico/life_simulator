# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:detector_baseline" do
  let(:experiment) { create(:experiment, slug: "room-to-grow", param_grid: { "max_tape_len" => [64, 512] }) }

  before do
    sampled(max_tape_len: 512, ratios: { 0 => 0.7, 250 => 0.66, 500 => 0.62, 750 => 0.58 })
    sampled(max_tape_len: 64, ratios: { 0 => 0.95, 250 => 0.94, 500 => 0.93, 750 => 0.92 })
  end

  it "prints the arm header" do
    expect(invoke("lab:detector_baseline", "room-to-grow"))
      .to match(/arm\s+n\s+max_tape_len\s+mean_compress_ratio\s+min_compress_ratio/)
  end

  it "reads the biased arm's window and its first crossing" do
    expect(invoke("lab:detector_baseline", "room-to-grow")).to match(/^\s*512\s+1\s+512\s+0\.66\s+0\.62\s+750\s+1$/)
  end

  it "leaves the arm that never crossed without a crossing epoch" do
    expect(invoke("lab:detector_baseline", "room-to-grow")).to match(/^\s*64\s+1\s+64\s+0\.94\s+0\.93\s+—\s+0$/)
  end

  it "counts the terminal runs it read" do
    expect(invoke("lab:detector_baseline", "room-to-grow")).to include("2 terminal runs read")
  end

  context "with no slug" do
    it "names every experiment's arms" do
      expect(invoke("lab:detector_baseline")).to match(/^\s*room-to-grow 512\s+1\s+512\s/)
    end
  end

  context "with FORMAT=csv" do
    it "writes the report as CSV" do
      csv = with_env("FORMAT", "csv") { invoke("lab:detector_baseline", "room-to-grow") }

      expect(CSV.parse(csv).first).to eq(Experiments::DetectorBaselineService::COLUMNS)
    end
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:detector_baseline", "colour") }.to raise_error(/Unknown experiment "colour"/)
  end

  def sampled(max_tape_len:, ratios:)
    run = create(:run, experiment: experiment, status: "finished",
                       params: Lab::Schema.run_defaults.merge("max_tape_len" => max_tape_len))
    ratios.each { |epoch, ratio| create(:sample, run: run, epoch: epoch, values: { "compress_ratio" => ratio }) }
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
