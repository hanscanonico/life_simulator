# frozen_string_literal: true

require "rails_helper"

RSpec.describe SnapshotReading, type: :model do
  it { is_expected.to belong_to(:run) }

  it "accepts a reading stepped a few epochs on from its stored world" do
    expect(build(:snapshot_reading, epoch: 1_005, source_epoch: 1_000)).to be_valid
  end

  it "accepts a reading of the stored world itself" do
    expect(build(:snapshot_reading, epoch: 1_000, source_epoch: 1_000)).to be_valid
  end

  it "rejects a reading taken before the world it came from" do
    expect(build(:snapshot_reading, epoch: 995, source_epoch: 1_000)).not_to be_valid
  end

  it "rejects a negative epoch" do
    expect(build(:snapshot_reading, epoch: -1, source_epoch: -1)).not_to be_valid
  end

  it "rejects a reading with no source epoch" do
    expect(build(:snapshot_reading, source_epoch: nil)).not_to be_valid
  end

  it "rejects an instrument with no version" do
    expect(build(:snapshot_reading, instrument: "oriented_census")).not_to be_valid
  end

  it "rejects values that are not an object" do
    expect(build(:snapshot_reading, values: [0.5])).not_to be_valid
  end

  it "rejects a second reading of the same epoch by the same instrument" do
    reading = create(:snapshot_reading)
    duplicate = build(:snapshot_reading, run: reading.run, instrument: reading.instrument, epoch: reading.epoch)

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "accepts the same epoch read by another instrument" do
    reading = create(:snapshot_reading)

    expect(create(:snapshot_reading, run: reading.run, instrument: "oriented_census/2", epoch: reading.epoch))
      .to be_persisted
  end

  it "goes with the run it reads" do
    reading = create(:snapshot_reading)

    expect { reading.run.destroy }.to change(described_class, :count).by(-1)
  end

  it "outlives the world it was read from" do
    snapshot = create(:snapshot, epoch: 1_000)
    create(:snapshot_reading, run: snapshot.run, epoch: 1_005, source_epoch: 1_000)

    expect { snapshot.destroy }.not_to change(described_class, :count)
  end
end
