# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::MetricSeriesService do
  subject(:series) { described_class.call(run: run, metric: "compress_ratio") }

  let(:run) { create(:run) }

  it "pairs every sampled epoch with its value, in epoch order" do
    create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })
    create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

    expect(series).to eq([[100, 0.9], [200, 0.4]])
  end

  it "is empty for a run that reported no sample" do
    expect(series).to eq([])
  end

  it "skips a sample that does not carry the metric" do
    create(:sample, run: run, epoch: 100, values: { "copy_rate" => 0.31 })
    create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })

    expect(series).to eq([[200, 0.4]])
  end

  it "skips a value that is not a number" do
    create(:sample, run: run, epoch: 100, values: { "compress_ratio" => "NaN" })

    expect(series).to eq([])
  end
end
