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
