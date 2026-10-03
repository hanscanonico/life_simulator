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

    it "takes a terminal world at exactly half replicators" do
      at_the_line = parent(share: 0.5)

      expect(build_sweep.parents).to eq([qualifying, at_the_line])
    end

    it "takes the reading at the terminal epoch whichever stored world it was stepped from" do
      create(:snapshot_reading, run: unread, epoch: unread.epochs, source_epoch: unread.epochs - 7,
                                values: { "replicator_share" => 0.9 })

      expect(build_sweep.parents).to eq([qualifying, unread])
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

    it "never takes a descendant as a parent" do
      root = parent(share: 0.9)
      child = Run.descend_from(root, params: root.params, seed: 5, budget: 1_000, experiment: source)
      child.update!(status: "finished")
      create(:snapshot, run: child, epoch: child.epochs)
      read(child, 0.9)

      expect(build_sweep.parents).to eq([root])
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

  describe "the metabolism sweep" do
    let(:definition) { Lab::SWEEPS.fetch("metabolism") }
    let(:experiment) do
      create(:experiment, slug: "metabolism", **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    # Sweep 9's eighteen qualifying economy-off controls, eleven at cap 128 and seven at 256,
    # beside a control that reads below half replicators.
    let!(:parents) do
      Array.new(11) { parent(share: 0.9) } +
        Array.new(7) { parent(share: 0.9, params: control_params.merge("max_tape_len" => 256)) }
    end

    before { parent(share: 0.3) }

    it "creates 108 children: eighteen parents, two arms, three seeds" do
      expect(build_sweep).to have_attributes(parents: parents, created: 108)
      expect(experiment.runs.pluck(:parent_run_id, :seed).tally)
        .to eq(parents.map(&:id).product([2001, 2002, 2003]).index_with(2))
    end

    it "merges the rewarded and the unpaid bundle over each parent's params" do
      build_sweep

      expect(experiment.runs.where(parent_run: parents.last, seed: 2002).order(:id).pluck(:params))
        .to eq(definition[:param_grid].fetch("treatment").map { |bundle| parents.last.params.merge(bundle) })
    end

    it "runs every child forty thousand epochs past its parent at priority 40" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_epoch, :epochs, :priority)).to eq([[1_000, 41_000, 40]])
    end

    it "adds nothing once built" do
      build_sweep

      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end
  end

  describe "the logic sweep" do
    let(:definition) { Lab::SWEEPS.fetch("logic") }
    let(:experiment) do
      create(:experiment, slug: "logic", **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    let(:metabolism) do
      create(:experiment, slug: "metabolism",
                          **Lab::SWEEPS.fetch("metabolism").slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    let!(:parents) do
      Array.new(11) { parent(share: 0.9) } +
        Array.new(7) { parent(share: 0.9, params: control_params.merge("max_tape_len" => 256)) }
    end

    before do
      parent(share: 0.3)
      described_class.call(metabolism)
    end

    it "creates 162 children: eighteen parents, three arms, three seeds" do
      expect(build_sweep).to have_attributes(parents: parents, created: 162)
      expect(experiment.runs.pluck(:parent_run_id, :seed).tally)
        .to eq(parents.map(&:id).product([2001, 2002, 2003]).index_with(3))
    end

    it "merges the full, the deep-only and the unpaid bundle over each parent's params" do
      build_sweep

      expect(experiment.runs.where(parent_run: parents.last, seed: 2002).order(:id).pluck(:params))
        .to eq(definition[:param_grid].fetch("treatment").map { |bundle| parents.last.params.merge(bundle) })
    end

    it "runs every child forty thousand epochs past its parent at priority 40" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_epoch, :epochs, :priority)).to eq([[1_000, 41_000, 40]])
    end

    it "adds nothing once built" do
      build_sweep

      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end

    it "leaves the metabolism sweep's 108 children as they were" do
      before = metabolism.runs.order(:id).pluck(:id, :params, :seed, :status)

      build_sweep

      expect(metabolism.runs.order(:id).pluck(:id, :params, :seed, :status)).to eq(before)
      expect(before.size).to eq(108)
    end
  end

  describe "the meta-stack sweep" do
    let(:definition) { Lab::SWEEPS.fetch("meta_stack") }
    let(:experiment) do
      create(:experiment, slug: "meta-stack", **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    let(:earlier) do
      %w[metabolism logic].map do |key|
        create(:experiment, slug: Lab.slug_for(key),
                            **Lab::SWEEPS.fetch(key).slice(:parents, :param_grid, :seeds, :epochs, :priority))
      end
    end
    let!(:parents) do
      Array.new(11) { parent(share: 0.9) } +
        Array.new(7) { parent(share: 0.9, params: control_params.merge("max_tape_len" => 256)) }
    end

    before do
      parent(share: 0.3)
      earlier.each { |sweep| described_class.call(sweep) }
    end

    it "creates 162 children: eighteen parents, three arms, three seeds" do
      expect(build_sweep).to have_attributes(parents: parents, created: 162)
      expect(experiment.runs.pluck(:parent_run_id, :seed).tally)
        .to eq(parents.map(&:id).product([2001, 2002, 2003]).index_with(3))
    end

    it "merges the stack, the deep-only stack and the in-place bundle over each parent's params" do
      build_sweep

      expect(experiment.runs.where(parent_run: parents.last, seed: 2002).order(:id).pluck(:params))
        .to eq(definition[:param_grid].fetch("treatment").map { |bundle| parents.last.params.merge(bundle) })
    end

    it "runs every child forty thousand epochs past its parent at priority 40" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_epoch, :epochs, :priority)).to eq([[1_000, 41_000, 40]])
    end

    it "adds nothing once built" do
      build_sweep

      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end

    it "leaves the metabolism sweep's 108 children and the logic sweep's 162 as they were" do
      before = earlier.map { |sweep| sweep.runs.order(:id).pluck(:id, :params, :seed, :status) }

      build_sweep

      expect(earlier.map { |sweep| sweep.runs.order(:id).pluck(:id, :params, :seed, :status) }).to eq(before)
      expect(before.map(&:size)).to eq([108, 162])
    end

    it "gives no child the canonical params of another child of the same parent and seed, in any of the three sweeps" do
      build_sweep

      keys = Run.where.not(parent_run_id: nil).map do |run|
        [Lab::CanonicalParams.for(run.params), run.seed, run.parent_run_id]
      end
      expect(keys.size).to eq(108 + 162 + 162)
      expect(keys.uniq).to eq(keys)
    end
  end

  describe "the topless-rise sweep" do
    let(:definition) { Lab::SWEEPS.fetch("topless_rise") }
    let(:experiment) do
      create(:experiment, slug: "topless-rise", **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    let(:meta_stack) do
      create(:experiment, slug: "meta-stack",
                          **Lab::SWEEPS.fetch("meta_stack").slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    let(:stack) do
      meta_stack.runs.order(:id).select { |run| Lab::MetaStackReading.treatment_key(run.params) == :meta_stack }
    end
    let(:unfinished) { stack.first }
    let(:unstored) { stack.second }
    let(:parents) { stack.drop(2) }

    before do
      2.times { parent(share: 0.9) }
      described_class.call(meta_stack)
      meta_stack.runs.each do |run|
        next if run == unfinished

        run.update!(status: "finished")
        create(:snapshot, run: run, epoch: run.epochs) unless run == unstored
      end
    end

    it "starts from every finished meta-stack-arm child that kept its last world, and from no other arm" do
      expect(build_sweep).to have_attributes(parents: parents, created: 12,
                                             skipped: { unfinished: [unfinished.id],
                                                        no_terminal_world: [unstored.id] })
      expect(experiment.runs.pluck(:parent_run_id, :seed).tally).to eq(parents.map(&:id).product([4001]).index_with(3))
    end

    it "merges the rise, capped and none bundles over each parent's params, keeping its tape and stack NAND" do
      build_sweep

      expect(experiment.runs.where(parent_run: parents.last).order(:id).pluck(:params))
        .to eq(definition[:param_grid].fetch("treatment").map { |bundle| parents.last.params.merge(bundle) })
      expect(experiment.runs.map { |run| run.params.values_at("meta_len", "logic_nand", "tasks") }.uniq)
        .to eq([[32, "stack", "logic4"]])
    end

    it "runs every child a hundred thousand epochs past its parent's last epoch at priority 40" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_epoch, :epochs, :priority)).to eq([[41_000, 141_000, 40]])
    end

    it "adds nothing once built" do
      build_sweep

      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end

    it "adds the children of a parent once it qualifies" do
      build_sweep
      unfinished.update!(status: "finished")
      create(:snapshot, run: unfinished, epoch: unfinished.epochs)

      expect { described_class.call(experiment.reload) }.to change(Run, :count).by(3)
    end

    it "leaves the meta-stack sweep's children as they were" do
      before = meta_stack.runs.order(:id).pluck(:id, :params, :seed, :status)

      build_sweep

      expect(meta_stack.runs.order(:id).pluck(:id, :params, :seed, :status)).to eq(before)
      expect(before.size).to eq(18)
    end
  end

  describe "the out-compute sweep" do
    let(:definition) { Lab::SWEEPS.fetch("out_compute") }
    let(:experiment) do
      create(:experiment, slug: "out-compute", **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
    end
    let(:reach) { reach_cap128_experiment }
    let!(:never_emerged) { reach_run(reach, shares: [0.0, 0.9, 0.9]) }
    let!(:half_empty) { reach_run(reach, crossing: 500, shares: [0.0, 0.9, 0.4]) }
    let!(:radius_one) { reach_run(reach, crossing: 500, shares: [0.0, 0.9, 0.9], params: { "radius" => 1 }) }
    let!(:parents) { Array.new(3) { reach_run(reach, crossing: 500, shares: [0.0, 0.9, 0.9]) } }

    it "starts from the emerged radius-4 runs whose terminal world is at least half replicators" do
      expect(build_sweep).to have_attributes(parents: parents, created: 12,
                                             skipped: { not_emerged: [never_emerged.id],
                                                        below_share: [half_empty.id] })
      expect(experiment.runs.pluck(:parent_run_id, :seed).tally).to eq(parents.map(&:id).product([6001]).index_with(4))
      expect(build_sweep.to_s).to include("not emerged: 1 (runs #{never_emerged.id})")
    end

    context "with more qualifying parents than the rule takes" do
      let(:limited) { definition.merge(parents: definition[:parents].merge("first" => 2)) }
      let(:experiment) do
        create(:experiment, slug: "out-compute", **limited.slice(:parents, :param_grid, :seeds, :epochs, :priority))
      end

      it "takes those with the lowest run ids and skips the rest as past the rule's first" do
        expect(build_sweep).to have_attributes(parents: parents.first(2),
                                               skipped: include(past_first: [parents.last.id]))
        expect(build_sweep.to_s).to include("past the rule's first qualifying parents: 1 (runs #{parents.last.id})")
      end
    end

    it "takes the first fifty-four qualifying parents" do
      expect(definition[:parents]).to include("first" => 54, "emerged" => true, "experiment" => "reach-cap128")
    end

    it "merges the four bundles over each parent's params, every child unpaid on the four-input ladder" do
      build_sweep

      expect(experiment.runs.where(parent_run: parents.last).order(:id).pluck(:params))
        .to eq(definition[:param_grid].fetch("treatment").map { |bundle| parents.last.params.merge(bundle) })
      expect(experiment.runs.map { |run| run.params.values_at("predation", "task_reward", "tasks", "radius") }.tally)
        .to eq(%w[subset_class equal shadow off].to_h { |relation| [[relation, 0, "logic4", 4], 3] })
    end

    it "runs every child a hundred thousand epochs past its parent's terminal epoch at priority 40" do
      build_sweep

      expect(experiment.runs.distinct.pluck(:parent_epoch, :epochs, :priority)).to eq([[2_000, 102_000, 40]])
    end

    it "adds nothing once built" do
      build_sweep

      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end

    it "gives every child of a parent its own canonical params" do
      build_sweep

      expect(experiment.runs.map { |run| [Lab::CanonicalParams.for(run.params), run.parent_run_id] }.uniq.size)
        .to eq(12)
    end

    it "stores a world every 500 epochs, so a finished child keeps one every 5 000 after pruning" do
      build_sweep
      child = experiment.runs.order(:id).first
      (child.parent_epoch + 500).step(child.epochs, 500) { |epoch| create(:snapshot, run: child, epoch: epoch) }
      child.update!(status: "finished")

      Runs::PruneSnapshotsService.call(run: child)

      expect(child.snapshots.order(:epoch).pluck(:epoch))
        .to eq([2_500, *(5_000..100_000).step(5_000), 102_000])
    end

    it "leaves the reach-cap128 runs as they were" do
      before = reach.runs.order(:id).pluck(:id, :params, :seed, :status)

      build_sweep

      expect(reach.runs.order(:id).pluck(:id, :params, :seed, :status)).to eq(before)
    end
  end

  context "with no source experiment seeded" do
    it "builds nothing" do
      expect(build_sweep).to have_attributes(parents: [], created: 0, skipped: {})
    end
  end
end
