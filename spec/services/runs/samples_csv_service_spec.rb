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

    blanks = Sample::OBSERVABLES.size - 1
    expect(rows.drop(1)).to eq([["100", "0.9", *[nil] * blanks], ["200", "0.4", *[nil] * blanks]])
  end

  it "leaves an observable the sample never reported empty" do
    create(:sample, run: run, epoch: 100, values: { "copy_rate" => 0.31 })

    expect(rows.last[Sample::OBSERVABLES.index("copy_rate") + 1]).to eq("0.31")
    expect(rows.last[1]).to be_nil
  end

  it "leaves the copy cost of a sample that reported none empty" do
    create(:sample, run: run, epoch: 100, values: { "copy_rate" => 0.31, "copy_cost" => nil })
    create(:sample, run: run, epoch: 200, values: { "copy_rate" => 0.31, "copy_cost" => 1_794 })

    column = Sample::OBSERVABLES.index("copy_cost") + 1
    expect(rows.pluck(column)).to eq(["copy_cost", nil, "1794"])
  end

  it "exports the complexity of the dominant replicator in its own two columns" do
    create(:sample, run: run, epoch: 100,
                    values: { "dominant_compressed_len" => 36, "dominant_instruction_count" => 15 })

    columns = %w[dominant_compressed_len dominant_instruction_count].map { |name| Sample::OBSERVABLES.index(name) + 1 }

    expect(rows.last.values_at(*columns)).to eq(%w[36 15])
  end

  it "reads no sample before the reader pulls the first row" do
    create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

    expect(queries_while { described_class.call(run: run).first }).to eq(0)
  end

  context "with more samples than one batch holds" do
    before do
      stub_const("#{described_class}::BATCH_SIZE", 100)
      samples = Array.new(500) { |index| { run_id: run.id, epoch: index * 10, values: { "compress_ratio" => 0.5 } } }
      Sample.upsert_all(samples, unique_by: %i[run_id epoch], record_timestamps: true)
    end

    it "reads them in a bounded number of queries" do
      lines = nil

      queries = queries_while { lines = described_class.call(run: run).to_a }

      expect(lines.size).to eq(501)
      expect(queries).to be <= 8
    end

    it "reads one batch to hand over the first row" do
      lines = described_class.call(run: run)

      expect(queries_while { lines.first(2) }).to eq(1)
    end
  end

  def queries_while(&read)
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &read)
    queries
  end
end
