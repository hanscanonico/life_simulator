# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::RescoresCsvService do
  subject(:rows) { CSV.parse(described_class.call(experiment: experiment).to_a.join) }

  let(:experiment) { create(:experiment, slug: "radius", param_grid: { "radius" => [1, 2, 4] }) }
  let(:run) { create(:run, experiment: experiment, seed: 7, params: { "radius" => 2 }) }

  it "heads the columns with the run, its arm and the readings" do
    expect(rows.first).to eq(%w[run_id seed arm epoch top_k] + Rescore::READINGS)
  end

  it "writes one row per reading, in run, epoch then top_k order" do
    create(:rescore, run: run, epoch: 200, top_k: 64)
    create(:rescore, run: run, epoch: 200, top_k: 16)
    create(:rescore, run: run, epoch: 100, top_k: 64)

    expect(rows.drop(1).map { |row| row.values_at(3, 4) })
      .to eq([%w[100 64], %w[200 16], %w[200 64]])
  end

  it "names the arm the run belongs to" do
    create(:rescore, run: run, epoch: 100, top_k: 16, replicator_count: 3, entropy_bits: 2.5)

    expect(rows.last.values_at(0, 1, 2)).to eq([run.id.to_s, "7", "radius 2"])
    expect(rows.last.values_at(5, 9)).to eq(%w[3 2.5])
  end

  context "with a sweep of no axis" do
    let(:experiment) { create(:experiment, slug: "baseline", param_grid: { "radius" => [1] }) }

    it "names the arm after the sweep" do
      create(:rescore, run: run, epoch: 100, top_k: 16)

      expect(rows.last[2]).to eq("baseline")
    end
  end

  context "with a reading the corpus pass left blank" do
    it "leaves its cell empty" do
      create(:rescore, run: run, epoch: 100, top_k: 16, replicator_count: nil)

      expect(rows.last[5]).to be_nil
    end
  end

  it "reads nothing before the reader pulls the first row" do
    create(:rescore, run: run, epoch: 100, top_k: 16)

    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.call(experiment: experiment).first
    end

    expect(queries).to eq(0)
  end

  it "reads the rescores of other experiments' runs into nobody's export" do
    create(:rescore, run: run, epoch: 100, top_k: 16)
    create(:rescore, epoch: 100, top_k: 16)

    expect(rows.drop(1).size).to eq(1)
  end

  context "with more readings than one batch holds" do
    it "walks the whole sort key" do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      3.times { |index| create(:rescore, run: run, epoch: index * 100, top_k: 16) }

      expect(rows.drop(1).pluck(3)).to eq(%w[0 100 200])
    end
  end
end
