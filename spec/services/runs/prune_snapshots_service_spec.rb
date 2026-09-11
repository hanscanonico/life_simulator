# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::PruneSnapshotsService do
  def snapshotted(epochs, **attributes)
    run = create(:run, status: "finished", finished_at: Time.current, epochs: epochs.max, **attributes)
    insert_snapshots(run, epochs)
    run
  end

  def kept(run) = run.snapshots.order(:epoch).pluck(:epoch)

  it "keeps the first, the last and every multiple of keep_every" do
    run = snapshotted((100..1_000).step(100).to_a)

    described_class.call(run: run, keep_every: 300)

    expect(kept(run)).to eq([100, 300, 600, 900, 1_000])
  end

  it "reports how many snapshots it deleted" do
    run = snapshotted((100..1_000).step(100).to_a)

    expect(described_class.call(run: run, keep_every: 300)).to eq(5)
  end

  context "when a run has fewer snapshots than the keep set" do
    it "keeps everything" do
      run = snapshotted([100, 200])

      described_class.call(run: run, keep_every: 1_000)

      expect(kept(run)).to eq([100, 200])
    end
  end

  it "keeps the single snapshot of a run that only posted one" do
    run = snapshotted([100])

    described_class.call(run: run, keep_every: 1_000)

    expect(kept(run)).to eq([100])
  end

  it "keeps the snapshot nearest a transition epoch that falls between two snapshots" do
    run = snapshotted((100..1_000).step(100).to_a, transition_epoch: 420)

    described_class.call(run: run, keep_every: 300)

    expect(kept(run)).to eq([100, 300, 400, 600, 900, 1_000])
  end

  context "when the transition epoch sits exactly between two" do
    it "keeps the lower snapshot" do
      run = snapshotted((100..1_000).step(100).to_a, transition_epoch: 450)

      described_class.call(run: run, keep_every: 300)

      expect(kept(run)).to include(400)
    end
  end

  it "leaves a running run alone: the runner resumes from its latest snapshot" do
    run = create(:run, :claimed, status: "running", epochs: 1_000)
    insert_snapshots(run, (100..1_000).step(100))

    expect { described_class.call(run: run, keep_every: 300) }.not_to(change { run.snapshots.count })
  end

  it "leaves a pending run alone" do
    run = create(:run, epochs: 1_000)
    insert_snapshots(run, (100..1_000).step(100))

    expect(described_class.call(run: run, keep_every: 300)).to eq(0)
  end

  it "prunes a failed run too" do
    run = snapshotted((100..1_000).step(100).to_a, status: "failed")

    expect { described_class.call(run: run, keep_every: 300) }.to change { run.snapshots.count }.from(10).to(5)
  end

  it "thins a run whose sweep varied snapshot_every by that run's own cadence" do
    run = snapshotted((200..4_000).step(200).to_a, params: Lab::Schema.run_defaults.merge("snapshot_every" => 200))

    described_class.call(run: run)

    expect(kept(run)).to eq([200, 2_000, 4_000])
  end

  it "defaults keep_every to ten snapshot cadences from the engine schema" do
    expect(described_class.default_keep_every).to eq(10 * Lab::Schema.defaults.fetch("snapshot_every"))
  end

  describe ".prunable" do
    it "finds a terminal run that finished inside the window and has snapshots to spare" do
      run = snapshotted((100..3_000).step(100).to_a)

      expect(described_class.prunable(since: 1.day.ago)).to include(run)
    end

    it "ignores a run that finished before the window" do
      run = snapshotted((100..3_000).step(100).to_a)
      run.update!(finished_at: 2.days.ago)

      expect(described_class.prunable(since: 1.day.ago)).to be_empty
    end

    it "ignores a run that is still running" do
      run = create(:run, :claimed, status: "running", epochs: 3_000, finished_at: Time.current)
      insert_snapshots(run, (100..3_000).step(100))

      expect(described_class.prunable(since: 1.day.ago)).to be_empty
    end

    it "ignores a run already thinned down to its keep set" do
      snapshotted([1_000, 2_000, 3_000])

      expect(described_class.prunable(since: 1.day.ago)).to be_empty
    end
  end
end
