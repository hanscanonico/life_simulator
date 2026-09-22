# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:backfill_emergence" do
  let!(:experiment) { create(:experiment, slug: "max-tape-len") }

  def sampled_run(counts, transition_epoch: 100, **attributes)
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch,
                       transition_epoch_constant: transition_epoch, **attributes)
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

    output = invoke("lab:backfill_emergence")

    expect(run.reload.emergence_epoch).to be_nil
    expect(output).to include("run #{run.id}: WARNING clearing emergence 100 by census")
  end

  it "leaves an emergence its own crossing still confirms exactly where it was" do
    run = sampled_run([0, 7], emergence_epoch: 100, emergence_witness: "census")

    output = invoke("lab:backfill_emergence")

    expect(run.reload).to have_attributes(emergence_epoch: 100, emergence_witness: "census")
    expect(output).not_to include("WARNING")
  end

  # Run 543's shape: the detector's crossing is the initial-condition false positive and
  # the world comes alive ten thousand epochs later (docs/design_record.md, 2026-09-15).
  context "with a run confirmed on a later crossing than the one the detector stored" do
    let!(:run) do
      run = create(:run, experiment: experiment, status: "finished", transition_epoch: 600,
                         transition_epoch_constant: 600)
      (0..20_000).step(100) do |epoch|
        create(:sample, run: run, epoch: epoch, values: values_at(epoch))
      end
      run
    end

    it "stores the confirmed crossing over the nil the first crossing left" do
      output = invoke("lab:backfill_emergence")

      expect(run.reload).to have_attributes(emergence_epoch: 12_500, emergence_witness: "census")
      expect(output).to include("run #{run.id}: crossing 600 → emerged at 12500 by census")
    end

    it "leaves the detector's crossing alone" do
      invoke("lab:backfill_emergence")

      expect(run.reload.transition_epoch).to eq(600)
    end

    def values_at(epoch)
      ratio = if epoch.between?(600, 900) then 0.45
              elsif epoch >= 12_500 then 0.22
              else 0.96
              end
      { "compress_ratio" => ratio, "op_density" => 0.1, "alphabet_size" => 200,
        "replicator_count" => epoch >= 12_700 ? 12 : 0, "copy_rate" => epoch >= 12_700 ? 0.01 : 0.0 }
    end
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
