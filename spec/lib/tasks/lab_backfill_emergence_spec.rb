# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:backfill_emergence" do
  let!(:experiment) { create(:experiment, slug: "max-tape-len") }

  def sampled_run(counts, transition_epoch: 100, **attributes)
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch, **attributes)
    counts.each_with_index do |count, index|
      create(:sample, run: run, epoch: transition_epoch + (index * 10),
                      values: { "replicator_count" => count, "copy_rate" => 0.0 })
    end
    run
  end

  it "stores the confirmed crossing and its witness" do
    run = sampled_run([0, 7])

    output = invoke("lab:backfill_emergence", "max-tape-len")

    expect(run.reload).to have_attributes(emergence_epoch: 100, emergence_witness: "census")
    expect(output).to include("run #{run.id}: crossing 100 → emerged at 100 by census")
  end

  it "leaves a crossing no witness backs unconfirmed" do
    run = sampled_run([0, 0])

    output = invoke("lab:backfill_emergence")

    expect(run.reload).to have_attributes(emergence_epoch: nil, emergence_witness: nil)
    expect(output).to include("run #{run.id}: crossing 100 → unconfirmed")
  end

  it "counts the flagged runs it confirmed over the terminal runs it read" do
    sampled_run([0, 7])
    sampled_run([0, 0])
    create(:run, experiment: experiment, status: "finished")

    expect(invoke("lab:backfill_emergence")).to include("confirmed 1 of 2 flagged runs, over 3 terminal runs")
  end

  it "clears an emergence the run's samples no longer confirm" do
    run = sampled_run([0, 0], emergence_epoch: 100, emergence_witness: "census")

    invoke("lab:backfill_emergence")

    expect(run.reload.emergence_epoch).to be_nil
  end

  it "reads terminal runs alone" do
    run = sampled_run([0, 7], status: "running")

    invoke("lab:backfill_emergence")

    expect(run.reload.emergence_epoch).to be_nil
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:backfill_emergence", "colour") }.to raise_error(/Unknown experiment "colour"/)
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
