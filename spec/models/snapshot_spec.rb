# frozen_string_literal: true

require "rails_helper"

RSpec.describe Snapshot, type: :model do
  it { is_expected.to belong_to(:run) }

  it "rejects a second snapshot for the same epoch of a run" do
    snapshot = create(:snapshot)

    expect(build(:snapshot, run: snapshot.run, epoch: snapshot.epoch)).not_to be_valid
  end

  it "rejects a world one byte over the cap" do
    snapshot = build(:snapshot, blob: "w" * (described_class::MAX_BYTES + 1))

    expect(snapshot).not_to be_valid
    expect(snapshot.errors[:blob]).to be_present
  end

  it "rejects a png one byte over the cap" do
    expect(build(:snapshot, png: "p" * (described_class::MAX_BYTES + 1))).not_to be_valid
  end

  it "accepts a world the size of the cap" do
    expect(build(:snapshot, blob: "w" * described_class::MAX_BYTES)).to be_valid
  end

  it "round-trips binary payloads" do
    snapshot = create(:snapshot, blob: "\x00\x01\x02", png: "\x89PNG")

    expect(snapshot.reload.blob).to eq("\x00\x01\x02")
  end
end
