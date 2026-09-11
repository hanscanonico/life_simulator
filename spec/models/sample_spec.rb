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

  describe "indexes" do
    let(:indexes) { described_class.connection.indexes(described_class.table_name) }

    it "indexes created_at for the status page's throughput window" do
      expect(indexes.map(&:columns)).to include(["created_at"])
    end

    it "indexes run_id for the samples a replicator was counted in" do
      index = indexes.find { |candidate| candidate.name == "index_samples_on_run_id_replicated" }

      expect(index).to have_attributes(columns: ["run_id"],
                                       where: a_string_including("'replicator_count'", "> '0'::jsonb"))
    end
  end
end
