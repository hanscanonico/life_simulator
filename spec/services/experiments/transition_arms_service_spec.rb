# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::TransitionArmsService do
  subject(:arms) { described_class.call(experiment: experiment) }

  let(:experiment) { create(:experiment, param_grid: { "mutation_rate" => [0.0, 0.000244] }) }

  before do
    sampled(transition_epoch: 200, replicators: [0, 4, 9])
    sampled(transition_epoch: 100, replicators: [0, 0, 0])
    sampled(transition_epoch: nil, replicators: [0, 2, 1])
  end

  it "counts the runs of an arm, its flags, its replicators and the runs holding both" do
    expect(arms.sole).to have_attributes(runs: 3, flagged: 2, replicated: 2, both: 1)
  end

  it "counts the runs the two observables disagree on" do
    expect(arms.sole.either_but_not_both).to eq(2)
  end

  it "names the arm the way the sweep's phase diagram does" do
    expect(arms.sole.label).to eq("0.000244")
  end

  describe "the census read at the wider window" do
    it "reads blank where no corpus pass measured the arm" do
      expect(arms.sole.replicated_wide).to be_nil
    end

    context "with a corpus pass that read the arm at top_k 16 and 64" do
      before do
        run = sampled(transition_epoch: nil, replicators: [0])
        create(:rescore, run: run, epoch: 100, top_k: 16, replicator_count: 0)
        create(:rescore, run: run, epoch: 100, top_k: 64, replicator_count: 5)
      end

      it "counts at 64 a run the locked window calls dead" do
        expect(arms.sole).to have_attributes(replicated: 2, replicated_wide: 1)
      end
    end

    context "with a corpus pass that found nothing at the wider window" do
      before do
        create(:rescore, run: sampled(transition_epoch: nil, replicators: [0]),
                         epoch: 100, top_k: 64, replicator_count: 0)
      end

      it "reads zero rather than blank" do
        expect(arms.sole.replicated_wide).to eq(0)
      end
    end
  end

  # TransitionReportService reads `peak_replicator_count.to_f.positive?` off the samples it
  # has already loaded; this block reads an indexed jsonb predicate. One definition.
  it "calls the same runs replicators as the transition report does" do
    report = Experiments::TransitionReportService.call(experiment: experiment, include_running: true)

    expect(arms.map { |arm| [arm.label, arm.replicated] })
      .to eq(report.arms.map { |arm| [arm.label, arm.replicated] })
  end

  context "with runs in two arms of the grid" do
    before { sampled(transition_epoch: 400, replicators: [7], mutation_rate: 0.0) }

    it "counts each arm on its own" do
      expect(arms.map { |arm| [arm.label, arm.runs, arm.both] }).to contain_exactly(["0.000244", 3, 1], ["0", 1, 1])
    end
  end

  context "with a run nothing has been sampled from" do
    before { create(:run, experiment: experiment) }

    it "leaves the unsampled run out of its arm" do
      expect(arms.sole.runs).to eq(3)
    end
  end

  context "with the counts read from the database" do
    it "costs the same number of queries at twelve sampled runs as at three" do
      three = queries_of_arms.size
      9.times { sampled(transition_epoch: 200, replicators: [3]) }

      expect(queries_of_arms.size).to eq(three)
    end

    it "reads no sample's values" do
      expect(queries_of_arms.grep(/"samples"\."values"/)).to be_empty
    end
  end

  def sampled(transition_epoch:, replicators:, mutation_rate: 0.000244)
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch,
                       params: Lab::Schema.run_defaults.merge("mutation_rate" => mutation_rate))
    replicators.each_with_index do |count, index|
      create(:sample, run: run, epoch: (index + 1) * 100,
                      values: { "compress_ratio" => 0.5, "replicator_count" => count })
    end
    run
  end

  def queries_of_arms
    queries = []
    collect = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
      described_class.call(experiment: experiment)
    end

    queries
  end
end
