# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::OrientedArmsService do
  let(:experiment) { create(:experiment, slug: "radius", param_grid: { "radius" => [1, 2] }) }
  let(:report) { described_class.call(experiment: experiment) }

  def finished_run(radius, **attributes)
    create(:run, experiment: experiment, status: "finished", epochs: 2_000,
                 params: Lab::Schema.run_defaults.merge("radius" => radius), **attributes)
  end

  def read(run, *shares)
    shares.each_with_index do |share, index|
      epoch = (index + 1) * 1_000
      create(:snapshot_reading, run: run, epoch: epoch, source_epoch: epoch, values: { "replicator_share" => share })
    end
  end

  def arm(label) = report.arms.find { |candidate| candidate.label == label }

  before do
    read(finished_run(1, transition_epoch: 500, emergence_epoch: 500, emergence_witness: "census"), 0.9, 0.9)
    read(finished_run(1, transition_epoch: 600), 0.6, 0.2)
    read(finished_run(1, transition_epoch: 700, emergence_epoch: 700, emergence_witness: "copy_rate"), 0.1, 0.2)
    finished_run(1, transition_epoch: 800, emergence_epoch: 800, emergence_witness: "census")
    read(finished_run(1), 0.1, 0.2)
    finished_run(1)
    read(finished_run(2), 0.3, 0.7)
  end

  it "counts each arm's runs, the measured ones and the detector's and the rule's calls" do
    expect(arm("1").cells.first(5)).to eq(["1", 6, 4, 4, 3])
  end

  it "counts the replicator worlds and the ones held to the end" do
    expect([arm("1").replicator_worlds, arm("1").held_to_end]).to eq([2, 1])
  end

  it "counts the runs the census and the rule disagree on, measured runs only" do
    expect([arm("1").replicators_not_emerged, arm("1").emerged_without_replicators]).to eq([1, 1])
  end

  it "reads the median first replicator epoch of the replicator worlds" do
    expect([arm("1").median_first_replicator_epoch, arm("2").median_first_replicator_epoch]).to eq([1_000, 2_000])
  end

  it "totals every arm" do
    expect(report.total.cells).to eq(["all", 7, 5, 4, 3, 3, 2, 2, 1, 1_000])
  end

  context "with runs that are no finished founding run" do
    before do
      parent = experiment.runs.find_by(transition_epoch: 500)
      read(create(:run, :descendant, experiment: experiment, parent_run: parent, params: parent.params,
                                     status: "finished"), 0.9, 0.9)
      read(create(:run, experiment: experiment, status: "running", params: parent.params), 0.9)
    end

    it "leaves them out" do
      expect(report.total.runs).to eq(7)
    end
  end

  it "costs two queries whatever the sweep holds" do
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.call(experiment: experiment).total.cells
    end

    expect(queries).to eq(2)
  end

  it "prints the arms and the total with the coarseness note" do
    text = report.to_text

    expect(text).to match(/arm\s+n\s+measured\s+flagged\s+emerged\s+replicator_worlds\s+held_to_end/)
    expect(text).to match(/^\s*all\s+7\s+5\s+4\s+3\s+3\s+2\s+2\s+1\s+1000$/)
    expect(text).to include("about every 1000 epochs")
  end

  it "writes the arms and their total as CSV" do
    expect(CSV.parse(report.to_csv)).to eq([described_class::COLUMNS, %w[1 6 4 4 3 2 1 1 1 1000],
                                            %w[2 1 1 0 0 1 1 1 0 2000], %w[all 7 5 4 3 3 2 2 1 1000]])
  end

  context "with a sweep no pass has read" do
    it "is unmeasured" do
      expect(described_class.call(experiment: create(:experiment))).not_to be_measured
    end
  end
end
