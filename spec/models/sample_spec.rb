# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sample, type: :model do
  it { is_expected.to belong_to(:run) }

  it "stores its metrics as data" do
    sample = create(:sample, values: { "compress_ratio" => 0.42 })

    expect(sample.reload.values).to eq({ "compress_ratio" => 0.42 })
  end

  it "rejects a second sample for the same epoch of a run" do
    sample = create(:sample)

    expect(build(:sample, run: sample.run, epoch: sample.epoch)).not_to be_valid
  end

  it "indexes created_at for the status page's throughput window" do
    columns = described_class.connection.indexes(described_class.table_name).map(&:columns)

    expect(columns).to include(["created_at"])
  end
end
