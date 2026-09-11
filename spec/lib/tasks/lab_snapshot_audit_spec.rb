# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:snapshot_audit" do
  let!(:experiment) { create(:experiment, slug: "mutation-rate") }
  let(:run) { create(:run, experiment: experiment, status: "finished", transition_epoch: 400) }

  it "prints the run header" do
    expect(invoke("lab:snapshot_audit", "mutation-rate"))
      .to match(/run_id\s+transition_epoch\s+snapshot_epoch\s+reason\s+epochs_away\s+samples_away/)
  end

  it "names the snapshot nearest the transition and why it was taken" do
    create(:snapshot, run: run, epoch: 300, reason: "cadence")
    create(:snapshot, run: run, epoch: 405, reason: "transition")

    expect(invoke("lab:snapshot_audit", "mutation-rate"))
      .to match(/^\s*#{run.id}\s+400\s+405\s+transition\s+5\s+1$/)
  end

  context "with two snapshots the same distance from the transition" do
    it "names the earlier one, the world the pruner keeps" do
      create(:snapshot, run: run, epoch: 410, reason: "cadence")
      create(:snapshot, run: run, epoch: 390, reason: "transition")

      expect(invoke("lab:snapshot_audit", "mutation-rate"))
        .to match(/^\s*#{run.id}\s+400\s+390\s+transition\s+10\s+1$/)
    end
  end

  it "counts the snapshots of the experiment by reason" do
    create(:snapshot, run: run, epoch: 300, reason: "cadence")
    create(:snapshot, run: run, epoch: 350, reason: "age")
    create(:snapshot, run: run, epoch: 405, reason: "transition")

    expect(invoke("lab:snapshot_audit", "mutation-rate"))
      .to include("snapshots by reason: cadence 1, age 1, transition 1")
  end

  it "counts a transition no snapshot came within one sample of" do
    create(:snapshot, run: run, epoch: 100, reason: "cadence")

    expect(invoke("lab:snapshot_audit", "mutation-rate"))
      .to include("1 runs with a transition, 1 of them with no snapshot within one sample")
  end

  context "with a transitioned run that never snapshotted" do
    it "leaves its snapshot columns blank" do
      run

      expect(invoke("lab:snapshot_audit", "mutation-rate")).to match(/^\s*#{run.id}\s+400\s+—\s+—\s+—\s+—$/)
    end
  end

  it "leaves out a run that settled no transition" do
    create(:run, experiment: experiment, status: "finished")

    expect(invoke("lab:snapshot_audit", "mutation-rate"))
      .to include("0 runs with a transition, 0 of them with no snapshot within one sample")
  end

  it "names a reason nothing was taken for" do
    create(:snapshot, run: run, epoch: 400, reason: "transition")

    expect(invoke("lab:snapshot_audit", "mutation-rate")).to include("cadence 0, age 0, transition 1")
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:snapshot_audit", "colour") }.to raise_error(/Unknown experiment "colour"/)
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
