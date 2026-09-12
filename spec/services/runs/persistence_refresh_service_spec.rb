# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::PersistenceRefreshService do
  let(:run) { create(:run, status: "finished", transition_epoch: 10) }

  before do
    [0.94, 0.5, 0.4, 0.3, 0.2].each_with_index do |ratio, index|
      create(:sample, run: run, epoch: index * 10, values: { "compress_ratio" => ratio, "replicator_count" => 7 })
    end
  end

  it "stores what the samples say became of the run" do
    expect(described_class.call(run: run)).to be(true)
    expect(run.reload.persistence_summary)
      .to have_attributes(census_peak: 7, peak_epoch: 0, epochs_persisted: 30, relapsed: false)
  end

  it "stores the summary under string keys" do
    described_class.call(run: run)

    expect(run.persistence.keys).to contain_exactly("census_peak", "peak_epoch", "epochs_persisted", "relapsed")
  end

  it "leaves a run whose stored summary already matches its samples alone" do
    described_class.call(run: run)

    expect { expect(described_class.call(run: run)).to be(false) }.not_to(change { run.reload.updated_at })
  end

  it "empties the summary of a run the detector no longer flags" do
    described_class.call(run: run)
    run.update!(transition_epoch: nil)

    expect(described_class.call(run: run)).to be(true)
    expect(run.reload.persistence).to eq({})
  end
end
