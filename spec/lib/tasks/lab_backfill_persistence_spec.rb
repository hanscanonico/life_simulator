# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:backfill_persistence" do
  let!(:experiment) { create(:experiment, slug: "bff-control") }
  let(:run) { create(:run, experiment: experiment, status: "finished", transition_epoch: 20) }

  before do
    [0.94, 0.94, 0.5, 0.4, 0.3, 0.2].each_with_index do |ratio, index|
      create(:sample, run: run, epoch: index * 10, values: { "compress_ratio" => ratio, "replicator_count" => 3 })
    end
  end

  it "derives the summary of a terminal run from its samples" do
    invoke("lab:backfill_persistence")

    expect(run.reload.persistence_summary)
      .to have_attributes(census_peak: 3, peak_epoch: 0, epochs_persisted: 30, relapsed: false)
  end

  it "changes nothing on a second pass" do
    invoke("lab:backfill_persistence", "bff-control")
    output = invoke("lab:backfill_persistence", "bff-control")

    expect(output).to include("summarised 0 of 1 terminal runs")
  end

  context "with a run the detector never flagged" do
    it "leaves the summary empty" do
      run.update!(transition_epoch: nil)

      invoke("lab:backfill_persistence")

      expect(run.reload.persistence).to eq({})
    end
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:backfill_persistence", "colour") }.to raise_error(/Unknown experiment "colour"/)
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
