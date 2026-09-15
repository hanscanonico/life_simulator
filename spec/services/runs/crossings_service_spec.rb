# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::CrossingsService do
  def samples(ratios)
    ratios.each_with_index.map { |ratio, index| [index * 10, { "compress_ratio" => ratio }] }
  end

  it "reads the first sample of a drop that holds" do
    expect(described_class.call(samples: samples([0.94, 0.94, 0.5, 0.4, 0.3, 0.2]))).to eq([20])
  end

  it "reads nothing out of a drop that recovers before the hold is up" do
    expect(described_class.call(samples: samples([0.94, 0.5, 0.4, 0.4, 0.94]))).to be_empty
  end

  it "reads nothing out of a run with no samples" do
    expect(described_class.call(samples: [])).to be_empty
  end

  it "reads every crossing a series holds, in epoch order" do
    ratios = [0.5, 0.4, 0.3, 0.2, 0.9, 0.9, 0.4, 0.3, 0.2, 0.1]

    expect(described_class.call(samples: samples(ratios))).to eq([0, 60])
  end

  it "reads one crossing out of a stretch that never recovers" do
    expect(described_class.call(samples: samples([0.4] * 20))).to eq([0])
  end

  it "reads nothing out of a drop whose alphabet collapsed" do
    collapsed = Array.new(6) { |index| [index * 10, { "compress_ratio" => 0.2, "alphabet_size" => 2 }] }

    expect(described_class.call(samples: collapsed)).to be_empty
  end
end
