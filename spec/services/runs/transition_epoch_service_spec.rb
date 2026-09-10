# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::TransitionEpochService do
  let(:run) { create(:run, status: "finished") }

  def record(series)
    series.each_with_index do |ratio, index|
      create(:sample, run: run, epoch: index * 10, values: { "compress_ratio" => ratio })
    end
  end

  it "reports the first sample of a drop that holds" do
    record([0.94, 0.94, 0.5, 0.4, 0.3, 0.2])

    expect(described_class.call(run: run)).to eq(20)
  end

  it "reports nothing for a drop that recovers before the hold is up" do
    record([0.94, 0.5, 0.4, 0.4, 0.94])

    expect(described_class.call(run: run)).to be_nil
  end

  it "reports nothing for a run with no samples" do
    expect(described_class.call(run: run)).to be_nil
  end

  it "reports the earliest drop that holds, not a later one" do
    record([0.5, 0.4, 0.9, 0.5, 0.4, 0.3, 0.2, 0.1, 0.05])

    expect(described_class.call(run: run)).to eq(30)
  end

  it "drops the candidate at a sample that carries no compress_ratio" do
    record([0.5, 0.4, 0.3])
    create(:sample, run: run, epoch: 5, values: { "distinct_tapes" => 3 })

    expect(described_class.call(run: run)).to be_nil
  end

  # The shape of production run 41: noise for 500 samples, then a fall that holds low.
  it "reads run 41's series the way the engine's tracker does" do
    ratios = ([0.94] * 500) + [0.725, 0.526, 0.052] + ([0.05] * 20)
    record(ratios)

    expect(described_class.call(run: run)).to eq(5010)
  end

  it "reports nothing while the drop is one sample short of the hold" do
    record([0.5, 0.4, 0.3])

    expect(described_class.call(run: run)).to be_nil
  end
end
