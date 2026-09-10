# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::SamplesCsvService do
  subject(:rows) { CSV.parse(described_class.call(run: run).to_a.join) }

  let(:run) { create(:run) }

  it "heads the columns with the epoch and the observables in the engine's order" do
    expect(rows.first).to eq(["epoch"] + Sample::OBSERVABLES)
    expect(Sample::OBSERVABLES.first).to eq("compress_ratio")
  end

  it "writes one row per sample, in epoch order" do
    create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })
    create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

    expect(rows.drop(1)).to eq([["100", "0.9", *[nil] * 6], ["200", "0.4", *[nil] * 6]])
  end

  it "leaves an observable the sample never reported empty" do
    create(:sample, run: run, epoch: 100, values: { "copy_rate" => 0.31 })

    expect(rows.last.last).to eq("0.31")
    expect(rows.last[1]).to be_nil
  end

  context "with more samples than one batch holds" do
    it "reads them in a bounded number of queries" do
      stub_const("#{described_class}::BATCH_SIZE", 100)
      samples = Array.new(500) { |index| { run_id: run.id, epoch: index * 10, values: { "compress_ratio" => 0.5 } } }
      Sample.upsert_all(samples, unique_by: %i[run_id epoch], record_timestamps: true)

      queries = 0
      counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      lines = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        described_class.call(run: run).to_a
      end

      expect(lines.size).to eq(501)
      expect(queries).to be <= 8
    end
  end
end
