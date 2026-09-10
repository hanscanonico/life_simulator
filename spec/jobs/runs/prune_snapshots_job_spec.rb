# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::PruneSnapshotsJob do
  it "prunes the runs that finished inside the window" do
    run = create(:run, status: "finished", finished_at: Time.current, epochs: 20_000)
    (100..20_000).step(100) { |epoch| create(:snapshot, run: run, epoch: epoch) }

    described_class.perform_now

    expect(run.snapshots.order(:epoch).pluck(:epoch)).to eq([100] + (1_000..20_000).step(1_000).to_a)
  end

  it "leaves a run that finished before the window alone" do
    run = create(:run, status: "finished", finished_at: 2.days.ago, epochs: 20_000)
    (100..20_000).step(100) { |epoch| create(:snapshot, run: run, epoch: epoch) }

    expect { described_class.perform_now }.not_to(change { run.snapshots.count })
  end

  it "reports how many snapshots it deleted" do
    run = create(:run, status: "finished", finished_at: Time.current, epochs: 1_000)
    (100..1_000).step(100) { |epoch| create(:snapshot, run: run, epoch: epoch) }

    expect(described_class.perform_now).to eq(8)
  end
end
