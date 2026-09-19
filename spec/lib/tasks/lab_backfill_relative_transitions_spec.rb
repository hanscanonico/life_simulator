# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:backfill_relative_transitions" do
  let!(:experiment) { create(:experiment, slug: "bff-control") }
  let(:run) { create(:run, experiment: experiment, status: "finished", transition_epoch: 510) }

  # A cap-64 arm: the run starts where the constant threshold was chosen, so the relative
  # rule reads the crossing the constant one stored.
  it "fills the relative epoch of a terminal run from its samples" do
    store(run, 0.98, 0.5)

    invoke("lab:backfill_relative_transitions")

    expect(run.reload.transition_epoch_relative).to eq(510)
  end

  it "leaves the locked reading alone" do
    store(run, 0.98, 0.5)

    invoke("lab:backfill_relative_transitions")

    expect(run.reload.transition_epoch).to eq(510)
  end

  context "with a run that starts near the threshold" do
    it "fills nothing, the fall being small against its own start" do
      store(run, 0.75, 0.46)

      invoke("lab:backfill_relative_transitions")

      expect(run.reload.transition_epoch_relative).to be_nil
    end
  end

  it "changes nothing on a second pass" do
    store(run, 0.98, 0.5)
    invoke("lab:backfill_relative_transitions", "bff-control")

    expect(invoke("lab:backfill_relative_transitions", "bff-control")).to include("backfilled 0 of 1 terminal runs")
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:backfill_relative_transitions", "colour") }.to raise_error(/Unknown experiment "colour"/)
  end

  def store(run, start, fallen)
    (0..50).each { |sample| create(:sample, run: run, epoch: sample * 10, values: values(start)) }
    (51..80).each { |sample| create(:sample, run: run, epoch: sample * 10, values: values(fallen)) }
  end

  def values(ratio)
    { "compress_ratio" => ratio, "op_density" => 0.5, "alphabet_size" => 200 }
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
