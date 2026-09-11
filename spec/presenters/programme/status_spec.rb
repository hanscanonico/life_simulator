# frozen_string_literal: true

require "rails_helper"

RSpec.describe Programme::Status do
  subject(:status) { described_class.build }

  def queries_during(&reading)
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &reading)
    queries
  end

  def read_every_value
    status.sweeps_queued
    status.runs_finished
    status.epochs_simulated
    status.seeds_transitioned
    status.peak_replicator_count
  end

  def sql_during(&reading)
    statements = []
    recorder = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record", &reading)
    statements.last
  end

  it "reads the whole strip in one query per value" do
    expect(queries_during { read_every_value }).to eq(5)
  end

  it "reads each value once, however often a page asks for it" do
    read_every_value

    expect(queries_during { read_every_value }).to eq(0)
  end

  context "with an empty lab" do
    it "reads zeros and no census" do
      expect(status.sweeps_queued).to eq(0)
      expect(status.runs_finished).to eq(0)
      expect(status.epochs_simulated).to eq(0)
      expect(status.seeds_transitioned).to eq(0)
      expect(status.peak_replicator_count).to be_nil
    end
  end

  context "with a seeded lab" do
    before do
      experiment = create(:experiment)
      create(:experiment)
      finished = create(:run, experiment: experiment, status: "finished", epochs_done: 900,
                              transition_epoch: 5_030)
      create(:run, experiment: experiment, status: "finished", epochs_done: 100)
      create(:run, experiment: experiment, status: "running", epochs_done: 7)
      create(:sample, run: finished, epoch: 100, values: { "replicator_count" => 12 })
      create(:sample, run: finished, epoch: 200, values: { "replicator_count" => 867 })
      create(:sample, run: finished, epoch: 300, values: { "replicator_count" => 0 })
    end

    it "counts the sweeps" do
      expect(status.sweeps_queued).to eq(2)
    end

    it "counts only the finished runs" do
      expect(status.runs_finished).to eq(2)
    end

    it "sums the epochs of every run, finished or not" do
      expect(status.epochs_simulated).to eq(1_007)
    end

    it "counts the finished runs that flagged a transition" do
      expect(status.seeds_transitioned).to eq(1)
    end

    it "takes the largest census any sample recorded" do
      expect(status.peak_replicator_count).to eq(867)
    end

    it "reads the census off the partial index, not off every sample" do
      sql = sql_during { status.peak_replicator_count }
      Sample.connection.execute("SET LOCAL enable_seqscan = off")

      plan = Sample.connection.select_values("EXPLAIN #{sql}").join("\n")

      expect(plan).to include("index_samples_on_run_id_replicated")
    end
  end

  context "with every census at zero" do
    it "reads no census at all" do
      create(:sample, values: { "replicator_count" => 0 })

      expect(status.peak_replicator_count).to be_nil
    end
  end
end
