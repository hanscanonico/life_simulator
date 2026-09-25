# frozen_string_literal: true

require "rails_helper"

# Whether the reading is final is held under a version of every row it reads; the test
# environment's null store would hide that, so this uses a real one. What final means is
# read through Experiments::FromEmergedReadingService's own spec.
RSpec.describe Experiments::DescendantSweepSettledService do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:definition) { Lab::SWEEPS.fetch("from_emerged") }
  let(:experiment) do
    create(:experiment, slug: "from-emerged", **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end
  let(:source) { create(:experiment, slug: "host-parasite") }
  let(:control_params) do
    Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0, "energy_stock_cap" => 4 * (2**13),
                                   "steal_loss" => 0.5, "max_tape_len" => 128, "tape_len" => 64,
                                   "width" => 128, "height" => 128, "mutation_rate" => Lab::EMERGENT_MUTATION_RATE)
  end

  def parent(share: 0.9)
    run = create(:run, :emerged, experiment: source, params: control_params, epochs: 1_000, emergence_epoch: 400)
    create(:snapshot, run: run, epoch: run.epochs)
    read(run, share: share) if share
    run
  end

  def read(run, share:)
    create(:snapshot_reading, run: run, epoch: run.epochs, source_epoch: run.epochs,
                              values: { "replicator_share" => share })
  end

  def settled = described_class.call(experiment)

  def uncached
    RSpec::Mocks.with_temporary_scope do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::NullStore.new)
      settled
    end
  end

  before do
    parent
    Experiments::DescendantSweepBuilderService.call(experiment)
    experiment.runs.update_all(status: "finished")
    allow(Rails).to receive(:cache).and_return(cache)
  end

  it "reads the same from the cache as from the pool" do
    settled

    expect([settled, uncached]).to eq([true, true])
  end

  it "reads the pool again once a child's status moves" do
    settled
    experiment.runs.first.update!(status: "running")

    expect([settled, uncached]).to eq([false, false])
  end

  # A corpus pass reads a parent's last world without touching the run.
  context "with a finished parent whose last world is not read yet" do
    let!(:unread) { parent(share: nil) }

    it "reads the pool again once the reading arrives" do
      expect(settled).to be(false)

      read(unread, share: 0.1)

      expect([settled, uncached]).to eq([true, true])
    end

    it "reads the pool again once that parent qualifies, and its children are missing" do
      settled
      read(unread, share: 0.9)

      expect([settled, uncached]).to eq([false, false])
    end
  end

  context "with a parent still running, whose reading will not qualify it" do
    let!(:running) { parent(share: 0.1).tap { |run| run.update!(status: "running") } }

    it "reads the pool again once that parent finishes" do
      expect(settled).to be(false)

      running.update!(status: "finished")

      expect([settled, uncached]).to eq([true, true])
    end
  end

  it "reads the pool again once a parent's last world is dropped" do
    settled
    Snapshot.where(run: source.runs).delete_all

    expect([settled, uncached]).to eq([false, false])
  end
end
