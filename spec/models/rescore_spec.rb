# frozen_string_literal: true

require "rails_helper"

RSpec.describe Rescore, type: :model do
  it { is_expected.to belong_to(:run) }

  it "rejects a second reading of the same epoch at the same top_k" do
    rescore = create(:rescore)

    expect(build(:rescore, run: rescore.run, epoch: rescore.epoch, top_k: rescore.top_k)).not_to be_valid
  end

  it "accepts the same epoch at another top_k" do
    rescore = create(:rescore, top_k: 16)

    expect(build(:rescore, run: rescore.run, epoch: rescore.epoch, top_k: 64)).to be_valid
  end

  it "rejects a top_k of zero" do
    expect(build(:rescore, top_k: 0)).not_to be_valid
  end

  it "rejects a negative epoch" do
    expect(build(:rescore, epoch: -1)).not_to be_valid
  end

  it "rejects a negative replicator count" do
    expect(build(:rescore, replicator_count: -1)).not_to be_valid
  end

  it "accepts a reading that measured nothing yet" do
    expect(build(:rescore, replicator_count: nil, top_share: nil)).to be_valid
  end

  it "goes with the run it reads" do
    rescore = create(:rescore)

    expect { rescore.run.destroy }.to change(described_class, :count).by(-1)
  end
end
