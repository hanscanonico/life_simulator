# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::EmergenceEpochService do
  let(:run) { create(:run, status: "finished", transition_epoch: 100) }

  def record(values_by_epoch)
    values_by_epoch.each { |epoch, values| create(:sample, run: run, epoch: epoch, values: values) }
  end

  it "confirms a crossing the replicator census backs within the window" do
    record(100 => { "replicator_count" => 0 }, 110 => { "replicator_count" => 12 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "census", confirmed?: true)
  end

  it "confirms a crossing only the copy rate backs" do
    record(100 => { "replicator_count" => 0, "copy_rate" => 0.0 },
           110 => { "replicator_count" => 0, "copy_rate" => 0.02 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "copy_rate")
  end

  it "confirms nothing for a crossing no witness backs" do
    record(100 => { "replicator_count" => 0, "copy_rate" => 0.0 },
           110 => { "replicator_count" => 0, "copy_rate" => 0.0 })

    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil, confirmed?: false)
  end

  it "confirms nothing for a run the detector never flagged" do
    run.update!(transition_epoch: nil)
    record(100 => { "replicator_count" => 12 })

    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil)
  end

  it "reads the census before the crossing, up to the width of the window" do
    (0..10).each { |index| create(:sample, run: run, epoch: index * 10, values: { "replicator_count" => 0 }) }
    run.samples.find_by(epoch: 0).update!(values: { "replicator_count" => 5 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "census")
  end

  it "reads no witness further from the crossing than the window" do
    (0..21).each { |index| create(:sample, run: run, epoch: index * 10, values: { "replicator_count" => 0 }) }
    run.samples.find_by(epoch: 210).update!(values: { "replicator_count" => 5 })

    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil)
  end

  it "confirms nothing for a flagged run nothing was ever sampled from" do
    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil)
  end

  it "reads the samples a caller has already loaded rather than the database" do
    emergence = described_class.call(transition_epoch: 100, samples: [[100, { "replicator_count" => 3 }]])

    expect(emergence).to have_attributes(epoch: 100, witness: "census")
  end
end
