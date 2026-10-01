# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:from_emerged_report" do
  let(:experiment) do
    create(:experiment, slug: "from-emerged",
                        **Lab::SWEEPS.fetch("from_emerged").slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  before do
    source = create(:experiment, slug: "host-parasite")
    params = Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 128)
    parent = create(:run, experiment: source, params: params, status: "finished", epochs: 1_000)
    create(:snapshot, run: parent, epoch: 1_000)
    create(:snapshot_reading, run: parent, epoch: 1_000, source_epoch: 1_000, values: { "replicator_share" => 0.9 })
    Experiments::DescendantSweepBuilderService.call(experiment)
  end

  after { ENV.delete("FORMAT") }

  it "prints every child under its treatment, labelled interim while they run" do
    expect(invoke("lab:from_emerged_report"))
      .to start_with("interim reading")
      .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+persistence\s+relapse_epoch/)
      .and match(/1003\s+host mode\s+pending/)
  end

  it "prints the arm verdicts" do
    expect(invoke("lab:from_emerged_report")).to match(/H-host\s+host mode\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
  end

  context "with FORMAT=csv" do
    it "writes CSV" do
      ENV["FORMAT"] = "csv"

      expect(CSV.parse(invoke("lab:from_emerged_report"))).to include(Lab::DescendantReading::CHILD_COLUMNS)
    end
  end

  context "with no from-emerged sweep seeded" do
    it "says so" do
      experiment.runs.delete_all
      experiment.delete

      expect { invoke("lab:from_emerged_report") }.to raise_error(/not seeded/)
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
