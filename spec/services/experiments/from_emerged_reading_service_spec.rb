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

  def parent(status: "finished")
    run = create(:run, :emerged, experiment: source, params: control_params, status: status, epochs: 1_000,
                                 emergence_epoch: 400)
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

  it "reads a child's own samples only, never its parent's epochs" do
    run = children(0).first
    create(:sample, run: run, epoch: run.parent_epoch, values: { "replicator_share" => 0.0 })
    sample(run)

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
  end
end
