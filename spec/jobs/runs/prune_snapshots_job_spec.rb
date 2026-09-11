# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::PruneSnapshotsJob do
  it "prunes the runs that finished inside the window" do
    run = create(:run, status: "finished", finished_at: Time.current, epochs: 3_000)
    insert_snapshots(run, (100..3_000).step(100))

    described_class.perform_now

    expect(run.snapshots.order(:epoch).pluck(:epoch)).to eq([100] + (1_000..3_000).step(1_000).to_a)
  end

  it "leaves a run that finished before the window alone" do
    run = create(:run, status: "finished", finished_at: 2.days.ago, epochs: 3_000)
    insert_snapshots(run, (100..3_000).step(100))

    expect { described_class.perform_now }.not_to(change { run.snapshots.count })
  end

  it "reports how many snapshots it deleted" do
    run = create(:run, status: "finished", finished_at: Time.current, epochs: 1_000)
    insert_snapshots(run, (100..1_000).step(100))

    expect(described_class.perform_now).to eq(8)
  end
end
