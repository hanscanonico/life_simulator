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

    context "with a descendant" do
      it "sums only the epochs it simulated past its parent's" do
        child = create(:run, :descendant, epochs_done: 1_250)

        expect(status.epochs_simulated).to eq(1_007 + child.parent_run.epochs_done + 250)
      end
    end

    it "takes the largest census any sample recorded" do
      expect(status.peak_replicator_count).to eq(867)
    end

    context "with a Metabolism run" do
      let!(:paid) do
        create(:run, :metabolism, status: "finished", epochs_done: 50, transition_epoch: 40).tap do |run|
          create(:sample, run: run, epoch: 100, values: { "replicator_count" => 5_000 })
        end
      end

      it "leaves its census out of the largest one" do
        expect(status.peak_replicator_count).to eq(867)
      end

      it "leaves its transition out of the count" do
        expect(status.seeds_transitioned).to eq(1)
      end

      it "still counts it among the runs finished and the epochs simulated" do
        expect([status.runs_finished, status.epochs_simulated]).to eq([3, 1_007 + paid.epochs_done])
      end
    end

    context "with a predation run" do
      let!(:predatory) do
        create(:run, :predatory, status: "finished", epochs_done: 50, transition_epoch: 40).tap do |run|
          create(:sample, run: run, epoch: 100, values: { "replicator_count" => 5_000 })
        end
      end

      it "leaves its census and its transition out" do
        expect([status.peak_replicator_count, status.seeds_transitioned]).to eq([867, 1])
      end

      it "still counts it among the runs finished and the epochs simulated" do
        expect([status.runs_finished, status.epochs_simulated]).to eq([3, 1_007 + predatory.epochs_done])
      end
    end

    context "with the unpaid run of a predation sweep's none arm" do
      it "keeps its census: a tape nothing reads leaves it plain Soup" do
        none = create(:run, params: Lab::Schema.run_defaults.merge(Lab::OutComputeReading::NONE_BUNDLE))
        create(:sample, run: none, epoch: 100, values: { "replicator_count" => 1_000 })

        expect(status.peak_replicator_count).to eq(1_000)
      end
    end

    context "with a run stored before the reward existed" do
      it "keeps its census" do
        predating = create(:run, params: Lab::Schema.run_defaults.except("task_reward"))
        create(:sample, run: predating, epoch: 100, values: { "replicator_count" => 1_000 })

        expect(status.peak_replicator_count).to eq(1_000)
      end
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
