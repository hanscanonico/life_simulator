# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::RecordReadingsService do
  let(:run) { create(:run, status: "finished") }
  let(:instrument) { "oriented_census/1" }

  def reading(epoch, share: 0.5)
    { "epoch" => epoch, "source_epoch" => epoch - 5,
      "values" => { "replicator_share" => share, "reverse_copy_rate" => 0.1 } }
  end

  def record(*readings, instrument: self.instrument)
    described_class.call(run: run, instrument: instrument, readings: readings)
  end

  it "stores one row per world read" do
    record(reading(105), reading(205))

    expect(run.snapshot_readings.order(:epoch).pluck(:epoch, :source_epoch)).to eq([[105, 100], [205, 200]])
  end

  it "stores the engine's values as they came" do
    record(reading(105, share: 0.25))

    expect(run.snapshot_readings.sole).to have_attributes(
      instrument: instrument, values: { "replicator_share" => 0.25, "reverse_copy_rate" => 0.1 },
      measured_at: be_present
    )
  end

  it "rewrites a world read again rather than adding a row" do
    record(reading(105, share: 0.0))
    record(reading(105, share: 0.75))

    expect(run.snapshot_readings.sole.values["replicator_share"]).to eq(0.75)
  end

  it "keeps another instrument's reading of the same world" do
    record(reading(105))
    record(reading(105), instrument: "oriented_census/2")

    expect(run.snapshot_readings.pluck(:instrument)).to contain_exactly(instrument, "oriented_census/2")
  end

  context "with a batch that reads one epoch twice" do
    it "keeps the later reading" do
      record(reading(105, share: 0.0), reading(105, share: 1.0))

      expect(run.snapshot_readings.sole.values["replicator_share"]).to eq(1.0)
    end
  end

  context "with an empty batch" do
    it "stores nothing" do
      expect { record }.not_to change(SnapshotReading, :count)
    end
  end

  context "with a malformed reading in the batch" do
    it "stores none of it" do
      expect { record(reading(105), reading(205).merge("source_epoch" => 300)) }
        .to raise_error(ActiveRecord::RecordInvalid)
      expect(SnapshotReading.count).to eq(0)
    end
  end

  it "leaves the run's own record alone" do
    run.update!(summary: { "replicator_count" => 3 }, transition_epoch: 400)
    create(:sample, run: run, epoch: 100)

    expect { record(reading(105)) }.not_to(change { [run.reload.attributes, run.samples.pluck(:values)] })
  end
end
