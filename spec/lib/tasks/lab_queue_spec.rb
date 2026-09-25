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

    it "raises the priority of a claimed run, which keeps it if its runner dies" do
      run = create(:run, :claimed, experiment: experiment, priority: 1)

      invoke("lab:prioritise", "bff-control", "9")

      expect(run.reload.priority).to eq(9)
    end

    it "leaves a finished run's priority alone" do
      run = create(:run, experiment: experiment, status: "finished", priority: 1)

      invoke("lab:prioritise", "bff-control", "9")

      expect(run.reload.priority).to eq(1)
    end

    it "prints the priority and the number of unfinished runs it moved" do
      create(:run, experiment: experiment)

      expect(invoke("lab:prioritise", "bff-control", "9")).to include("priority 9, 1 unfinished runs")
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

  describe "lab:prioritise_run" do
    let(:experiment) { create(:experiment, slug: "bff-control", priority: 0) }

    it "raises the priority of the run alone" do
      run = create(:run, experiment: experiment, priority: 0)
      sibling = create(:run, experiment: experiment, priority: 0)

      invoke("lab:prioritise_run", run.id.to_s, "9")

      expect([run.reload.priority, sibling.reload.priority, experiment.reload.priority]).to eq([9, 0, 0])
    end

    it "raises the priority of a running run, which keeps it if its runner dies" do
      run = create(:run, :claimed, experiment: experiment, status: "running", priority: 1)

      invoke("lab:prioritise_run", run.id.to_s, "9")

      expect(run.reload.priority).to eq(9)
    end

    it "prints the run, its arm and the move" do
      run = create(:run, experiment: experiment, seed: 5, priority: 2)

      expect(invoke("lab:prioritise_run", run.id.to_s, "9"))
        .to include("run #{run.id} (bff-control, seed 5): priority 2 → 9")
    end

    it "refuses a finished run and leaves its priority alone" do
      run = create(:run, experiment: experiment, status: "finished", priority: 1)

      expect { invoke("lab:prioritise_run", run.id.to_s, "9") }
        .to raise_error(/Run #{run.id} is finished/)
      expect(run.reload.priority).to eq(1)
    end

    it "refuses a run it does not know" do
      expect { invoke("lab:prioritise_run", "404", "9") }.to raise_error(/Unknown run "404"/)
    end

    it "refuses a priority that is not an integer" do
      run = create(:run, experiment: experiment)

      expect { invoke("lab:prioritise_run", run.id.to_s, "urgent") }
        .to raise_error(/Priority "urgent" is not an integer/)
    end
  end

  describe "lab:backfill_transitions" do
    let(:experiment) { create(:experiment, slug: "bff-control", status: "finished") }

    # A baseline window at `start`, then a fall to `fallen` past it: at 0.98 and 0.5 both
    # rules read the crossing at epoch 510, the arms the constant threshold was chosen on.
    def run_with_drop(start: 0.98, fallen: 0.5, **attributes)
      create(:run, experiment: experiment, status: "finished", **attributes).tap do |run|
        (0..50).each { |sample| create(:sample, run: run, epoch: sample * 10, values: values(start)) }
        (51..80).each { |sample| create(:sample, run: run, epoch: sample * 10, values: values(fallen)) }
      end
    end

    def values(ratio) = { "compress_ratio" => ratio, "op_density" => 0.5, "alphabet_size" => 200 }

    it "fills the transition epoch of a run measured before the relock" do
      run = run_with_drop(transition_epoch: nil, transition_epoch_constant: 510)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload).to have_attributes(transition_epoch: 510, transition_epoch_constant: 510)
    end

    it "clears the epoch of a run that never fell far from its own start" do
      run = run_with_drop(start: 0.75, fallen: 0.46, transition_epoch: 510, transition_epoch_constant: 510)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload).to have_attributes(transition_epoch: nil, transition_epoch_constant: 510)
    end

    it "recomputes the persistence summary against the epoch it has just rewritten" do
      run = run_with_drop(transition_epoch: nil)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload.persistence_summary).to have_attributes(epochs_persisted: 290, relapsed: false)
    end

    it "clears a transition epoch the samples do not support" do
      run = create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                         transition_epoch_constant: 900)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload).to have_attributes(transition_epoch: nil, transition_epoch_constant: nil)
    end

    it "leaves a run whose epochs and summary already match its samples alone" do
      run = run_with_drop(transition_epoch: 510, transition_epoch_constant: 510)
      Runs::PersistenceRefreshService.call(run: run)
      output = nil

      expect { output = invoke("lab:backfill_transitions", "bff-control") }
        .not_to(change { run.reload.updated_at })
      expect(output).to eq("backfilled 0 of 1 terminal runs\n")
    end

    # The relock renamed the columns rather than moving their contents, so a run can carry
    # the epochs the rule now says it has and a summary read by the rule it replaced.
    it "resummarises a run whose epochs did not move" do
      run = run_with_drop(transition_epoch: 510, transition_epoch_constant: 510,
                          persistence: { "census_peak" => nil, "peak_epoch" => nil,
                                         "epochs_persisted" => 390, "relapsed" => false })

      expect(invoke("lab:backfill_transitions", "bff-control"))
        .to include("run #{run.id}: persistence", "backfilled 1 of 1 terminal runs")
      expect(run.reload.persistence_summary.epochs_persisted).to eq(290)
    end

    it "leaves the runs still in the queue alone" do
      run = create(:run, :claimed, experiment: experiment, transition_epoch: 900)

      invoke("lab:backfill_transitions", "bff-control")

      expect(run.reload.transition_epoch).to eq(900)
    end

    it "prints each run's old and new epochs and a total" do
      run = run_with_drop(transition_epoch: nil, transition_epoch_constant: 510)

      expect(invoke("lab:backfill_transitions", "bff-control"))
        .to include("run #{run.id}: none → 510, constant 510 → 510", "backfilled 1 of 1 terminal runs")
    end

    it "covers every experiment with no slug given" do
      run = run_with_drop(transition_epoch: nil)
      other = create(:run, experiment: create(:experiment, slug: "radius"), status: "finished",
                           transition_epoch: 900)

      invoke("lab:backfill_transitions")

      expect([run.reload.transition_epoch, other.reload.transition_epoch]).to eq([510, nil])
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

  describe "lab:prioritise_seed_major" do
    let(:experiment) { create(:experiment, slug: "bff-control", priority: 0) }

    it "puts the experiment at the base and each unfinished run at base minus its seed" do
      runs = [0, 1, 2].map { |seed| create(:run, experiment: experiment, seed: seed, priority: 0) }

      invoke("lab:prioritise_seed_major", "bff-control", "40")

      expect([experiment.reload.priority, *runs.map { |run| run.reload.priority }]).to eq([40, 40, 39, 38])
    end

    it "leaves a finished run's priority alone" do
      run = create(:run, experiment: experiment, seed: 1, status: "finished", priority: 1)

      invoke("lab:prioritise_seed_major", "bff-control", "40")

      expect(run.reload.priority).to eq(1)
    end

    it "leaves another experiment's runs alone" do
      create(:run, experiment: experiment, seed: 0)
      other = create(:run, experiment: create(:experiment, slug: "room-to-grow", priority: 5), seed: 1, priority: 5)

      invoke("lab:prioritise_seed_major", "bff-control", "40")

      expect(other.reload.priority).to eq(5)
    end

    it "prints the count moved and the band it wrote" do
      [0, 1].each { |seed| create(:run, experiment: experiment, seed: seed) }

      expect(invoke("lab:prioritise_seed_major", "bff-control", "40"))
        .to include("priority 40, 2 unfinished runs over priorities 39..40")
    end

    it "names no band of priorities it did not write" do
      create(:run, experiment: experiment, seed: 1, status: "finished", priority: 1)

      expect(invoke("lab:prioritise_seed_major", "bff-control", "40"))
        .to include("priority 40, 0 unfinished runs\n")
    end

    it "refuses an experiment it does not know" do
      expect { invoke("lab:prioritise_seed_major", "colour", "40") }.to raise_error(/Unknown experiment "colour"/)
    end

    it "refuses a base that is not an integer" do
      experiment

      expect { invoke("lab:prioritise_seed_major", "bff-control", "urgent") }
        .to raise_error(/Priority "urgent" is not an integer/)
    end
  end

  describe "lab:prioritise_runs" do
    let(:experiment) { create(:experiment, slug: "bff-control", priority: 0) }

    it "moves every run of the batch and leaves the experiment alone" do
      runs = create_list(:run, 2, experiment: experiment, priority: 0)

      invoke("lab:prioritise_runs", "#{runs.first.id}:40;#{runs.second.id}:39")

      expect([*runs.map { |run| run.reload.priority }, experiment.reload.priority]).to eq([40, 39, 0])
    end

    it "prints one line per run and the count moved" do
      run = create(:run, experiment: experiment, seed: 7, priority: 3)

      expect(invoke("lab:prioritise_runs", "#{run.id}:40"))
        .to include("run #{run.id} (bff-control, seed 7): priority 3 → 40", "1 runs moved")
    end

    it "refuses a malformed batch before moving anything" do
      run = create(:run, experiment: experiment, priority: 0)

      expect { invoke("lab:prioritise_runs", "#{run.id}:40;oops") }
        .to raise_error(/Malformed pairs "oops"/)
      expect(run.reload.priority).to eq(0)
    end

    it "refuses a batch holding a run it does not know" do
      expect { invoke("lab:prioritise_runs", "#{Run.maximum(:id).to_i + 1}:40") }
        .to raise_error(/Unknown runs/)
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
