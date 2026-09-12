# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "the lab queue tasks" do
  describe "lab:requeue_failed" do
    let(:experiment) { create(:experiment, slug: "bff-control", status: "running") }

    it "turns the failed runs of the experiment pending" do
      run = create(:run, :claimed, experiment: experiment, status: "failed", epochs_done: 1_200,
                                   started_at: 1.hour.ago, finished_at: 1.minute.ago, error: "boom",
                                   summary: { "replicators" => 3 }, transition_epoch: 900)

      invoke("lab:requeue_failed", "bff-control")

      expect(run.reload).to have_attributes(status: "pending", runner_id: nil, claimed_at: nil,
                                            heartbeat_at: nil, started_at: nil, finished_at: nil,
                                            error: nil, epochs_done: 0, summary: {},
                                            transition_epoch: nil)
    end

    it "leaves a claimed run of the experiment alone" do
      run = create(:run, :claimed, experiment: experiment)

      invoke("lab:requeue_failed", "bff-control")

      expect(run.reload.status).to eq("claimed")
    end

    it "prints how many runs it requeued" do
      create(:run, experiment: experiment, status: "failed")

      expect(invoke("lab:requeue_failed", "bff-control")).to include("1 failed runs back to pending")
    end

    it "refuses an experiment it does not know" do
      expect { invoke("lab:requeue_failed", "colour") }.to raise_error(/Unknown experiment "colour"/)
    end
  end

  describe "lab:prioritise" do
    let(:experiment) { create(:experiment, slug: "bff-control", priority: 0) }

    it "raises the priority of the experiment and of its pending runs" do
      run = create(:run, experiment: experiment)

      invoke("lab:prioritise", "bff-control", "9")

      expect([experiment.reload.priority, run.reload.priority]).to eq([9, 9])
    end

    it "leaves a claimed run's priority alone" do
      run = create(:run, :claimed, experiment: experiment, priority: 1)

      invoke("lab:prioritise", "bff-control", "9")

      expect(run.reload.priority).to eq(1)
    end

    it "prints the priority and the number of pending runs it moved" do
      create(:run, experiment: experiment)

      expect(invoke("lab:prioritise", "bff-control", "9")).to include("priority 9, 1 pending runs")
    end

    it "refuses an experiment it does not know" do
      expect { invoke("lab:prioritise", "colour", "9") }.to raise_error(/Unknown experiment "colour"/)
    end

    it "refuses a priority that is not an integer" do
      experiment

      expect { invoke("lab:prioritise", "bff-control", "urgent") }
        .to raise_error(/Priority "urgent" is not an integer/)
    end
  end

  describe "lab:backfill_transitions" do
    let(:experiment) { create(:experiment, slug: "bff-control", status: "finished") }

    def run_with_drop(**attributes)
      create(:run, experiment: experiment, status: "finished", **attributes).tap do |run|
        [0.94, 0.5, 0.4, 0.3, 0.2].each_with_index do |ratio, index|
          create(:sample, run: run, epoch: index * 10, values: { "compress_ratio" => ratio })
        end
      end
    end

    it "rewrites the transition epoch of a terminal run measured before the resume fix" do
      run = run_with_drop(transition_epoch: 40)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload.transition_epoch).to eq(10)
    end

    it "recomputes the persistence summary against the epoch it has just rewritten" do
      run = run_with_drop(transition_epoch: 40)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload.persistence_summary).to have_attributes(epochs_persisted: 30, relapsed: false)
    end

    it "clears a transition epoch the samples do not support" do
      run = create(:run, experiment: experiment, status: "finished", transition_epoch: 900)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload.transition_epoch).to be_nil
    end

    it "leaves a run whose recorded epoch already matches its samples alone" do
      run = run_with_drop(transition_epoch: 10)
      output = nil

      expect { output = invoke("lab:backfill_transitions", "bff-control") }
        .not_to(change { run.reload.updated_at })
      expect(output).to eq("backfilled 0 of 1 terminal runs\n")
    end

    it "leaves the runs still in the queue alone" do
      run = create(:run, :claimed, experiment: experiment, transition_epoch: 900)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload.transition_epoch).to eq(900)
    end

    it "prints each run's old and new epoch and a total" do
      run = run_with_drop(transition_epoch: 40)

      expect(invoke("lab:backfill_transitions", "bff-control"))
        .to include("run #{run.id}: 40 → 10", "backfilled 1 of 1 terminal runs")
    end

    it "covers every experiment with no slug given" do
      run = run_with_drop(transition_epoch: 40)
      other = create(:run, experiment: create(:experiment, slug: "radius"), status: "finished",
                           transition_epoch: 900)

      invoke("lab:backfill_transitions")

      expect([run.reload.transition_epoch, other.reload.transition_epoch]).to eq([10, nil])
    end

    it "refuses an experiment it does not know" do
      expect { invoke("lab:backfill_transitions", "colour") }.to raise_error(/Unknown experiment "colour"/)
    end
  end

  describe "lab:discard_pending" do
    let(:experiment) { create(:experiment, slug: "radius") }

    def run_on(radius, *traits)
      create(:run, *traits, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => radius))
    end

    it "deletes the pending runs of the arm and prints their ids" do
      discarded = run_on(64)
      kept = run_on(1)

      output = invoke("lab:discard_pending", "radius", "radius", "64")

      expect(output).to include("discarded 1 pending runs #{discarded.id}")
      expect(experiment.runs.pluck(:id)).to eq([kept.id])
    end

    it "leaves a claimed run of the arm alone" do
      run = run_on(64, :claimed)

      invoke("lab:discard_pending", "radius", "radius", "64")

      expect(run.reload).to be_claimed
    end

    it "refuses an experiment it does not know" do
      expect { invoke("lab:discard_pending", "colour", "radius", "64") }
        .to raise_error(/Unknown experiment "colour"/)
    end

    it "refuses a call with no value" do
      experiment

      expect { invoke("lab:discard_pending", "radius", "radius") }.to raise_error(/Give a parameter and a value/)
    end
  end

  describe "lab:discard_duplicates" do
    let(:experiment) { create(:experiment, slug: "radius") }

    it "keeps one run per arm and seed and prints the ids it removed" do
      kept = create(:run, experiment: experiment, seed: 3)
      duplicate = create(:run, experiment: experiment, seed: 3, params: Lab::Schema.run_defaults)

      output = invoke("lab:discard_duplicates", "radius")

      expect(output).to include("discarded 1 duplicate pending runs #{duplicate.id}")
      expect(experiment.runs.pluck(:id)).to eq([kept.id])
    end

    it "leaves a running duplicate alone" do
      running = create(:run, :claimed, experiment: experiment, seed: 3, status: "running")
      create(:run, :claimed, experiment: experiment, seed: 3, status: "running",
                             params: Lab::Schema.run_defaults)

      invoke("lab:discard_duplicates", "radius")

      expect([running.reload.status, experiment.runs.count]).to eq(["running", 2])
    end

    it "refuses an experiment it does not know" do
      expect { invoke("lab:discard_duplicates", "colour") }.to raise_error(/Unknown experiment "colour"/)
    end
  end

  describe "lab:sweep" do
    it "carries a sweep definition's priority to the experiment and its runs" do
      stub_const("Lab::SWEEPS", { "control" => sweep_definition })

      invoke("lab:sweep", "control")

      expect([Experiment.find_by(slug: "control").priority, Run.distinct.pluck(:priority)]).to eq([4, [4]])
    end

    def sweep_definition
      { name: "Control", description: "A priority sweep", priority: 4,
        param_grid: { "mutation_rate" => [0.0] }, seeds: [1], epochs: 100 }
    end
  end

  def invoke(name, *args)
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task[name]
    task.reenable
    original = $stdout
    $stdout = StringIO.new
    task.invoke(*args)
    $stdout.string
  ensure
    $stdout = original
  end
end
