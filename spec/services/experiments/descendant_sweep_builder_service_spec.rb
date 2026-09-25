# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::DescendantSweepBuilderService do
  subject(:build_sweep) { described_class.call(experiment) }

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

  # A finished run of `source` with its terminal world stored, and the oriented census of
  # that world when `share` is given.
  def parent(share:, params: control_params, status: "finished")
    run = create(:run, experiment: source, params: params, status: status, epochs: 1_000)
    create(:snapshot, run: run, epoch: run.epochs)
    read(run, share) unless share.nil?
    run
  end

  def read(run, share)
    create(:snapshot_reading, run: run, epoch: run.epochs, source_epoch: run.epochs,
                              values: { "replicator_share" => share })
  end

  describe "qualification" do
    let!(:half_empty) { parent(share: 0.4) }
    let!(:qualifying) { parent(share: 0.6) }
    let!(:unread) { parent(share: nil) }

    it "starts children only from a parent whose terminal world is at least half replicators" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_run_id)).to eq([qualifying.id])
    end

    it "reports each skipped parent under its reason" do
      expect(build_sweep.skipped).to eq(below_share: [half_empty.id], no_reading: [unread.id])
    end

    it "reads the reading at the terminal epoch, not an earlier one" do
      create(:snapshot_reading, run: unread, epoch: 900, source_epoch: 900, values: { "replicator_share" => 0.9 })

      expect(build_sweep.skipped[:no_reading]).to eq([unread.id])
    end

    it "reads only the instrument the rule names" do
      create(:snapshot_reading, run: unread, instrument: "census/1", epoch: unread.epochs,
                                source_epoch: unread.epochs, values: { "replicator_share" => 0.9 })

      expect(build_sweep.skipped[:no_reading]).to eq([unread.id])
    end

    it "prints the skips with their run ids" do
      expect(build_sweep.to_s)
        .to eq("1 qualifying parents, 12 children created; skipped no reading of the last world: 1 " \
               "(runs #{unread.id}); share below the minimum: 1 (runs #{half_empty.id})")
    end
  end

  describe "the parent pool" do
    it "skips a parent still running" do
      running = parent(share: 0.9, status: "running")

      expect(build_sweep.skipped).to eq(unfinished: [running.id])
    end

    it "skips a parent that kept no world at its last epoch" do
      run = create(:run, experiment: source, params: control_params, status: "finished", epochs: 1_000)
      read(run, 0.9)

      expect(build_sweep.skipped).to eq(no_terminal_world: [run.id])
    end

    it "takes parents from both economy-off controls and no other arm" do
      roomy = parent(share: 0.9, params: control_params.merge("max_tape_len" => 256))
      parent(share: 0.9, params: control_params.merge("energy_influx" => 2**11, "steal_amount" => 2**10))

      expect(build_sweep.parents).to eq([roomy])
    end

    it "takes no parent from another experiment" do
      create(:run, experiment: create(:experiment), params: control_params, status: "finished")

      expect(build_sweep.parents).to be_empty
    end
  end

  describe "the pairing" do
    let!(:parents) { [parent(share: 0.6), parent(share: 0.97, params: control_params.merge("max_tape_len" => 256))] }

    it "observes every (parent, seed) under every treatment" do
      build_sweep

      expect(experiment.runs.pluck(:parent_run_id, :seed).tally)
        .to eq(parents.map(&:id).product([1001, 1002, 1003]).index_with(4))
    end

    it "merges each treatment over its parent's params" do
      build_sweep

      parents.each do |run|
        expect(experiment.runs.where(parent_run: run, seed: 1001).order(:id).pluck(:params))
          .to eq(definition[:param_grid].fetch("treatment").map { |treatment| run.params.merge(treatment) })
      end
    end

    it "starts every child at its parent's last epoch and runs it the sweep's budget past it" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_epoch, :epochs, :epochs_done)).to eq([[1_000, 21_000, 1_000]])
    end

    it "keeps the continuation child's params equal to its parent's" do
      build_sweep

      expect(experiment.runs.where(parent_run: parents.first).order(:id).first.params).to eq(parents.first.params)
    end

    it "queues the experiment" do
      build_sweep

      expect(experiment).to be_queued
    end
  end

  describe "re-seeding" do
    let!(:first) { parent(share: 0.8) }
    let!(:later) { parent(share: nil) }

    before { described_class.call(experiment) }

    it "adds nothing once built" do
      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end

    it "adds exactly the four treatments times three seeds of a parent that qualified since" do
      read(later, 0.7)

      expect { described_class.call(experiment.reload) }.to change(Run, :count).by(12)
      expect(experiment.runs.where(parent_run: first).count).to eq(12)
    end
  end

  describe "structure" do
    it "refuses a treatment that would change the parent's world and creates nothing" do
      parent(share: 0.9)
      experiment.update!(param_grid: { "treatment" => [{}, { "max_tape_len" => 512 }] })

      expect { build_sweep }.to raise_error(ActiveRecord::RecordInvalid, /structure/)
      expect(experiment.runs.count).to eq(0)
    end
  end

  describe "priority" do
    it "puts every child ahead of sweep 9's extension" do
      parent(share: 0.9)

      build_sweep

      expect(experiment.runs.distinct.pluck(:priority)).to eq([50])
    end
  end

  context "with no source experiment seeded" do
    it "builds nothing" do
      expect(build_sweep).to have_attributes(parents: [], created: 0, skipped: {})
    end
  end
end
