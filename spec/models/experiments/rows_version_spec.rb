# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::RowsVersion do
  let(:experiment) { create(:experiment) }
  let!(:run) { create(:run, experiment: experiment) }

  def version = described_class.of(experiment.runs, SnapshotReading, Rescore)

  it "holds while nothing is written" do
    expect(version).to eq(version)
  end

  it "reads each table in one statement" do
    queries = []
    collect = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(collect, "sql.active_record") { version }

    expect(queries.size).to eq(1)
  end

  it "moves once a row is added" do
    before = version
    create(:rescore, run: run)

    expect(version).not_to eq(before)
  end

  it "moves once a row is upserted with new values" do
    reading = create(:snapshot_reading, run: run, values: { "replicator_share" => 0.1 })
    before = version
    Runs::RecordReadingsService.call(run: run, instrument: reading.instrument,
                                     readings: [{ "epoch" => reading.epoch, "source_epoch" => reading.source_epoch,
                                                  "values" => { "replicator_share" => 0.9 } }])

    expect(version).not_to eq(before)
  end

  it "moves once a row is deleted" do
    create(:rescore, run: run)
    before = version
    Rescore.delete_all

    expect(version).not_to eq(before)
  end

  it "ignores the rows of another experiment's runs" do
    before = version
    create(:rescore)

    expect(version).to eq(before)
  end
end
