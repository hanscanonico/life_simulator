# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::FromEmergedReadingService do
  subject(:report) { described_class.call(experiment: experiment) }

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
  let!(:parents) { [parent, parent] }

  def parent(status: "finished", seed: nil)
    run = create(:run, :emerged, experiment: source, params: control_params, status: status, epochs: 1_000,
                                 emergence_epoch: 400, **{ seed: seed }.compact)
    create(:snapshot, run: run, epoch: run.epochs)
    create(:snapshot_reading, run: run, epoch: run.epochs, source_epoch: run.epochs,
                              values: { "replicator_share" => 0.9 })
    run
  end

  def children(treatment_index)
    bundle = definition[:param_grid].fetch("treatment")[treatment_index]
    experiment.runs.order(:parent_run_id, :seed).select do |run|
      Experiments::Axis.sweep(experiment.param_grid).first.value_of(run.params) == bundle
    end
  end

  # 100 own samples: a steady share, and a self-replicating dominant tape whose instruction
  # count reads `first` over the first decile and `last` over the last.
  def sample(run, first: 100, last: 100, share: 0.9, status: "finished")
    insert_own_samples(run, Array.new(100) do |index|
      { "replicator_share" => share.respond_to?(:call) ? share.call(index) : share,
        "dominant_self_replicates" => true, "dominant_instruction_count" => index >= 90 ? last : first,
        "steal_rate" => 0.02, "distinct_tapes" => 300 }
    end)
    run.update!(status: status)
  end

  before { Experiments::DescendantSweepBuilderService.call(experiment) }

  it "names the treatments for what they do" do
    expect(report.arms.map(&:name)).to eq(["continuation", "economy 2048", "economy 8192", "host mode"])
  end

  it "pairs each treated arm against the continuation under its hypothesis" do
    expect(report.comparisons.keys.map { |treatment| [treatment.hypothesis, treatment.name] })
      .to eq([["H-economy", "economy 2048"], ["H-economy", "economy 8192"], ["H-host", "host mode"]])
  end

  context "with every child finished, the priced arm rising and the continuation flat" do
    before do
      experiment.runs.each { |run| sample(run) }
      children(1).each { |run| run.samples.delete_all && sample(run, last: 120) }
    end

    it "is final" do
      expect(report).not_to be_interim
    end

    it "counts each treatment's verdicts" do
      expect(report.arms.map { |arm| arm.cells.first(9) })
        .to eq([["continuation", 6, 6, 6, 0, 0, 6, 0, 0], ["economy 2048", 6, 6, 6, 0, 6, 0, 0, 0],
                ["economy 8192", 6, 6, 6, 0, 0, 6, 0, 0], ["host mode", 6, 6, 6, 0, 0, 6, 0, 0]])
    end

    it "holds H-economy for the rising arm on six discordant pairs" do
      comparison = report.comparisons.values.first

      expect(comparison).to have_attributes(outcome: :held, measured_count: 6, favouring: 6, p_value: Rational(1, 64))
    end

    it "refutes H-host, whose arm rises no more often than the continuation" do
      expect(report.comparisons.values.last.outcome).to eq(:refuted)
    end

    it "holds H-persistence and says the constant-hazard hypothesis had no relapse to read" do
      expect(report.persistence_line)
        .to eq("H-persistence held: 0 of 6 continuation children relapsed; the colonies persisted over the " \
               "budget and the constant-hazard hypothesis had no relapse to be read on")
    end

    it "reads only the priced arms' steal rate" do
      expect(report.arms.map(&:steal_rate)).to eq([nil, 0.02, 0.02, nil])
    end

    it "prints the per-child table, the arms and the verdicts" do
      expect(report.to_text).to start_with("final reading\n")
        .and match(/economy 2048\s+finished\s+held\s+—\s+—\s+\d+–\d+\s+rises\s+100\s+120$/)
        .and include("H-economy  economy 2048")
    end

    it "writes the same tables as CSV" do
      expect(CSV.parse(report.to_csv)).to include(Lab::DescendantReading::COMPARISON_COLUMNS)
    end
  end

  context "with a continuation child that relapsed" do
    before do
      experiment.runs.each { |run| sample(run) }
      relapsing = children(0).first
      relapsing.samples.delete_all
      sample(relapsing, share: ->(index) { index >= 50 ? 0.05 : 0.9 })
    end

    it "refutes H-persistence" do
      expect(report.persistence).to have_attributes(outcome: :refuted, relapsed: [have_attributes(seed: 1001)])
    end

    it "gives the relapse its epoch and its colony age, counted from the parent's emergence" do
      child = report.persistence.relapsed.first

      expect([child.reading.relapse_epoch, child.relapse_colony_age]).to eq([1_510, 1_110])
    end

    it "does not read a treated arm relapsing less as killing replicators" do
      expect(report.comparisons.values.map(&:kills?)).to eq([false, false, false])
    end
  end

  context "with a treated arm relapsing more often than the continuation" do
    before do
      experiment.runs.each { |run| sample(run) }
      children(3).each { |run| run.samples.delete_all && sample(run, share: 0.05) }
    end

    it "prints its test but does not read it as H-host" do
      expect(report.comparisons.values.last).to have_attributes(kills?: true, reading: :kills)
    end
  end

  # Its first two own samples sit below the floor: with the sample at its parent epoch they
  # would make the three running that read as a relapse.
  it "reads a child's own samples only, never one at its parent epoch" do
    run = children(0).first
    create(:sample, run: run, epoch: run.parent_epoch, values: { "replicator_share" => 0.0 })
    sample(run, share: ->(index) { index < 2 ? 0.05 : 0.9 })

    expect(report.children.find { |child| child.run_id == run.id }.reading.persistence).to eq(:held)
  end

  describe "interim against final" do
    context "with a child still running" do
      before do
        experiment.runs.each { |run| sample(run) }
        experiment.runs.first.update!(status: "running")
      end

      it "is interim" do
        expect(report.to_text).to start_with("interim reading")
      end
    end

    context "with a candidate parent still running" do
      before do
        experiment.runs.each { |run| sample(run) }
        create(:run, experiment: source, params: control_params, status: "running")
      end

      it "is interim: that parent may yet qualify" do
        expect(report).to be_interim
      end
    end

    context "with a finished parent whose last world is not read yet" do
      before do
        experiment.runs.each { |run| sample(run) }
        unread = create(:run, experiment: source, params: control_params, status: "finished", epochs: 1_000)
        create(:snapshot, run: unread, epoch: unread.epochs)
      end

      it "is interim" do
        expect(report).to be_interim
      end
    end

    context "with a qualifying parent missing some of its children" do
      before do
        experiment.runs.each { |run| sample(run) }
        children(3).first.destroy!
      end

      it "is interim" do
        expect(report).to be_interim
      end
    end

    context "with a child that failed" do
      before do
        experiment.runs.each { |run| sample(run) }
        experiment.runs.first.update!(status: "failed")
      end

      it "is interim until it is re-run: the entry reads every child finished" do
        expect(report).to be_interim
      end
    end
  end

  describe "the held-out confirmatory reading" do
    # One parent of the first ninety seeds, whose children were seen, and two of the extension.
    let!(:parents) { [parent(seed: 5), parent(seed: 120), parent(seed: 121)] }

    let(:heldout) { report.heldout }

    # 200 own samples every 10 epochs, so the last 100 are past the settling window: their
    # first decile reads `first` for `copy_latency` and their last `last`.
    def settled_sample(run, first: 4_000, last: 4_000, share: 0.9)
      insert_own_samples(run, Array.new(200) do |index|
        { "replicator_share" => share, "dominant_self_replicates" => true, "dominant_instruction_count" => 100,
          "copy_latency" => index >= 190 ? last : first }
      end)
      run.update!(status: "finished")
    end

    context "with no child of a held-out parent" do
      let!(:parents) { [parent(seed: 5)] }

      it "holds no child and says so" do
        expect(heldout.to_text(final: report.final)).to eq("held-out reading: no held-out child yet")
      end
    end

    context "with every child sampled and the rich economy's copiers getting faster" do
      before do
        experiment.runs.each { |run| settled_sample(run) }
        children(2).each { |run| run.samples.delete_all && settled_sample(run, last: 2_000) }
      end

      it "reads the extension parents' children only" do
        expect(heldout.children.map(&:parent_id).uniq).to eq(parents.drop(1).map(&:id))
      end

      it "tests H3-latency and H4-survivors on the economy arms, not on host mode" do
        expect(heldout.tests.map { |test| [test.hypothesis, test.treatment.name] })
          .to eq([["H3-latency", "economy 2048"], ["H4-survivors", "economy 2048"],
                  ["H3-latency", "economy 8192"], ["H4-survivors", "economy 8192"]])
      end

      it "shows H3-latency for the rich economy on six pairs, and refutes it where every pair ties" do
        expect(heldout.tests.select { |test| test.hypothesis == "H3-latency" }.map(&:outcome_label))
          .to eq(%w[refuted shown])
      end

      it "counts every held-out child's latency as measured" do
        expect(heldout.arms.map(&:cells)).to all(match([anything, 6, 6, 0, 0, 6, 6]))
      end

      it "prints the held-out tables" do
        expect(heldout.to_text(final: report.final)).to start_with("held-out reading, final\n")
          .and match(/H3-latency\s+economy 8192\s+6\s+6\s+0\s+0\s+0\.0156\s+shown/)
      end

      it "writes the same tables as CSV" do
        expect(CSV.parse(heldout.to_csv(final: report.final))).to include(Lab::FromEmergedHeldout::TEST_COLUMNS)
      end
    end

    context "with a held-out economy child extinct" do
      before do
        experiment.runs.each { |run| settled_sample(run) }
        extinct = children(1).find { |run| run.parent_run_id == parents.last.id }
        extinct.samples.delete_all
        settled_sample(extinct, share: 0.01)
      end

      it "counts it extinct and a settled relapse" do
        expect(heldout.arms.second.cells).to eq(["economy 2048", 6, 6, 1, 1, 5, 5])
      end

      it "leaves its pair out of both tests" do
        expect(heldout.tests.first(2).map { |test| test.comparison.measured_count }).to eq([5, 5])
      end
    end
  end

  # A running sweep's children touch their runs with every sample batch, so each child's
  # reading is held on its own; the test environment's null store would hide that.
  describe "each child's reading, held on its own" do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      experiment.runs.each { |run| sample(run, share: ->(index) { 0.6 + (index % 7 * 0.05) }) }
      children(1).each { |run| run.samples.delete_all && sample(run, last: 120) }
    end

    def with_cache
      RSpec::Mocks.with_temporary_scope do
        allow(Rails).to receive(:cache).and_return(cache)
        yield
      end
    end

    # The runs whose samples were read, by the run id each sample query is bound to.
    def runs_read(&)
      runs = []
      collect = lambda do |*, payload|
        runs << payload[:binds].first.value if payload[:sql].include?("FROM \"samples\"")
      end
      ActiveSupport::Notifications.subscribed(collect, "sql.active_record", &)
      runs
    end

    it "reads the same from the cache as from the samples" do
      uncached = described_class.call(experiment: experiment)
      with_cache { described_class.call(experiment: experiment) }
      cached = with_cache { described_class.call(experiment: experiment) }

      expect([cached.children, cached.to_text, cached.to_csv])
        .to eq([uncached.children, uncached.to_text, uncached.to_csv])
    end

    it "reads a child's samples again only once it has posted more" do
      with_cache { described_class.call(experiment: experiment) }
      posting = children(0).first
      Runs::RecordSamplesService.call(run: posting, samples: [{ "epoch" => 5_000, "replicator_share" => 0.01 }])

      expect(runs_read { with_cache { described_class.call(experiment: experiment) } }).to eq([posting.id])
    end
  end
end
