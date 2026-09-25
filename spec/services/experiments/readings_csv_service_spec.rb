# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ReadingsCsvService do
  subject(:rows) { CSV.parse(described_class.call(experiment: experiment, instrument: instrument).to_a.join) }

  let(:instrument) { "oriented_census/1" }
  let(:experiment) { create(:experiment, slug: "radius", param_grid: { "radius" => [1, 2, 4] }) }
  let(:run) { create(:run, experiment: experiment, seed: 7, params: { "radius" => 2 }) }

  def read(epoch, values: { "replicator_share" => 0.5 }, run: self.run, instrument: self.instrument)
    create(:snapshot_reading, run: run, instrument: instrument, epoch: epoch, source_epoch: epoch - 5,
                              values: values)
  end

  it "heads the columns with the run, its arm, the epochs and the instrument's keys in name order" do
    read(105, values: { "reverse_copy_rate" => 0.1, "replicator_share" => 0.5 })

    expect(rows.first).to eq(%w[run_id seed arm epoch source_epoch replicator_share reverse_copy_rate])
  end

  it "writes one row per reading, in run then epoch order" do
    read(205)
    read(105)

    expect(rows.drop(1).map { |row| row.values_at(3, 4) }).to eq([%w[105 100], %w[205 200]])
  end

  it "names the arm the run belongs to" do
    read(105, values: { "replicator_share" => 0.25 })

    expect(rows.last).to eq([run.id.to_s, "7", "radius 2", "105", "100", "0.25"])
  end

  context "with a reading that lacks a key another carries" do
    it "leaves its cell empty" do
      read(105, values: { "replicator_share" => 0.5 })
      read(205, values: { "replicator_share" => 0.5, "reverse_copy_rate" => 0.1 })

      expect(rows[1].last).to be_nil
    end
  end

  it "leaves out other instruments and other experiments' runs" do
    read(105)
    read(105, instrument: "other_census/1", values: { "other" => 1 })
    read(105, run: create(:run))

    expect(rows.first).not_to include("other")
    expect(rows.drop(1).size).to eq(1)
  end

  context "with more readings than one batch holds" do
    it "walks the whole sort key" do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      [105, 205, 305].each { |epoch| read(epoch) }

      expect(rows.drop(1).pluck(3)).to eq(%w[105 205 305])
    end
  end

  it "reads nothing before the reader pulls the first row" do
    read(105)

    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.call(experiment: experiment, instrument: instrument)
    end

    expect(queries).to eq(0)
  end
end
