# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::DetectorBaselineService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { create(:experiment, slug: "max-tape-len", param_grid: { "max_tape_len" => [64, 512] }) }

  before do
    sampled(max_tape_len: 512, ratios: { 0 => 0.72, 250 => 0.65, 500 => 0.61, 750 => 0.58, 1_000 => 0.5 })
    sampled(max_tape_len: 64, ratios: { 0 => 0.98, 250 => 0.97, 500 => 0.96, 750 => 0.95, 5_000 => 0.4 })
  end

  it "reads one arm per swept value" do
    expect(report.arms.map(&:label)).to contain_exactly("64", "512")
  end

  it "reads the arm's tape cap beside its ratios" do
    expect(arm("512")).to have_attributes(runs: 1, max_tape_len: "512")
  end

  it "means the compress ratio over the first 500 epochs only" do
    expect(arm("512").mean_compress_ratio).to be_within(1e-9).of((0.72 + 0.65 + 0.61) / 3)
  end

  it "mins the compress ratio over the same window" do
    expect(arm("512").min_compress_ratio).to be_within(1e-9).of(0.61)
  end

  it "leaves the unbiased arm's window well above the threshold" do
    expect(arm("64").mean_compress_ratio).to be_within(1e-9).of((0.98 + 0.97 + 0.96) / 3)
  end

  it "reads the first crossing of the threshold" do
    expect(arm("512").mean_first_crossing_epoch).to eq(750)
  end

  it "shares out the runs that crossed early" do
    expect([arm("512").early_crossing_share, arm("64").early_crossing_share]).to eq([1.0, 0.0])
  end

  context "with a second run in the arm" do
    before { sampled(max_tape_len: 512, ratios: { 0 => 0.62, 500 => 0.58, 600 => 0.55 }) }

    it "weighs each run of the arm once" do
      expect(arm("512").mean_first_crossing_epoch).to eq(625)
    end

    it "means the run means rather than pooling samples of unequal cadence" do
      expect(arm("512").mean_compress_ratio)
        .to be_within(1e-9).of((((0.72 + 0.65 + 0.61) / 3) + ((0.62 + 0.58) / 2)) / 2)
    end

    it "counts both runs" do
      expect(arm("512").runs).to eq(2)
    end
  end

  context "with a run still going" do
    before { sampled(max_tape_len: 512, ratios: { 0 => 0.1 }, status: "running") }

    it "leaves the partial reading out" do
      expect(arm("512").runs).to eq(1)
    end
  end

  context "with a run nothing was sampled from" do
    before { create(:run, experiment: experiment, status: "finished", params: params_for(512)) }

    it "leaves it out" do
      expect(arm("512").runs).to eq(1)
    end
  end

  context "with no experiment given" do
    subject(:report) { described_class.call }

    before do
      other = create(:experiment, slug: "radius", param_grid: { "radius" => [1, 4] })
      sampled(max_tape_len: 64, ratios: { 0 => 0.9 }, sweep: other, params: { "radius" => 4 })
    end

    it "names every experiment's arms" do
      expect(report.arms.map(&:label)).to contain_exactly("max-tape-len 64", "max-tape-len 512", "radius 4")
    end
  end

  it "prints the columns aligned" do
    expect(report.to_text.lines.first).to match(/arm\s+n\s+max_tape_len\s+mean_compress_ratio/)
  end

  it "counts the runs it read under the table" do
    expect(report.to_text).to include("2 terminal runs read")
  end

  it "writes the same arms as CSV" do
    expect(CSV.parse(report.to_csv).first).to eq(described_class::COLUMNS)
  end

  def arm(label) = report.arms.find { |candidate| candidate.label == label }

  def sampled(max_tape_len:, ratios:, status: "finished", sweep: nil, params: {})
    run = create(:run, experiment: sweep || experiment, status: status,
                       params: params_for(max_tape_len).merge(params))
    ratios.each do |epoch, ratio|
      create(:sample, run: run, epoch: epoch, values: { "compress_ratio" => ratio, "distinct_tapes" => 16_384 })
    end
  end

  def params_for(max_tape_len) = Lab::Schema.run_defaults.merge("max_tape_len" => max_tape_len)
end
