# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:from_emerged_heldout_report" do
  let(:experiment) do
    create(:experiment, slug: "from-emerged",
                        **Lab::SWEEPS.fetch("from_emerged").slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end
  let(:source) { create(:experiment, slug: "host-parasite") }

  before { experiment }

  after { ENV.delete("FORMAT") }

  def qualifying_parent(seed:)
    params = Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 128)
    parent = create(:run, experiment: source, params: params, seed: seed, status: "finished", epochs: 1_000)
    create(:snapshot, run: parent, epoch: 1_000)
    create(:snapshot_reading, run: parent, epoch: 1_000, source_epoch: 1_000, values: { "replicator_share" => 0.9 })
    Experiments::DescendantSweepBuilderService.call(experiment)
  end

  context "with the children of seen parents only" do
    before { qualifying_parent(seed: 12) }

    it "says no held-out child exists yet" do
      expect(invoke("lab:from_emerged_heldout_report")).to eq("held-out reading: no held-out child yet")
    end
  end

  context "with the children of an extension parent" do
    before { qualifying_parent(seed: 140) }

    it "prints every held-out child and the tests, labelled interim while they run" do
      expect(invoke("lab:from_emerged_heldout_report"))
        .to start_with("held-out reading, interim")
        .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+settled_relapse_epoch/)
        .and match(/H3-latency\s+economy 8192\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
    end

    context "with FORMAT=csv" do
      it "writes CSV" do
        ENV["FORMAT"] = "csv"

        expect(CSV.parse(invoke("lab:from_emerged_heldout_report"))).to include(Lab::FromEmergedHeldout::CHILD_COLUMNS)
      end
    end
  end

  context "with no from-emerged sweep seeded" do
    it "says so" do
      experiment.delete

      expect { invoke("lab:from_emerged_heldout_report") }.to raise_error(/not seeded/)
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
