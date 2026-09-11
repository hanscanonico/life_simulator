# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::TransitionReportService do
  subject(:report) { described_class.call(experiment: experiment) }

  let(:experiment) { create(:experiment, param_grid: { "mutation_rate" => [0.0, 0.000244] }) }

  let!(:true_positive) do
    sampled(transition_epoch: 200,
            samples: [sample(0.9, entropy: 5.0, replicators: 0, copy_rate: 0.0, tapes: 900, top_share: 0.02),
                      sample(0.5, entropy: 3.0, replicators: 4, copy_rate: 0.002, tapes: 400, top_share: 0.2),
                      sample(0.4, entropy: 2.0, replicators: 9, copy_rate: 0.005, tapes: 120, top_share: 0.41)])
  end

  let!(:entropy_only) do
    sampled(transition_epoch: 100,
            samples: [sample(0.55, entropy: 2.5, replicators: 0, copy_rate: 0.0001, tapes: 300, top_share: 0.3),
                      sample(0.5, entropy: 1.5, replicators: 0, copy_rate: 0.0001, tapes: 200, top_share: 0.5),
                      sample(0.45, entropy: 1.0, replicators: 0, copy_rate: 0.0, tapes: 150, top_share: 0.6)])
  end

  let!(:replicator_only) do
    sampled(transition_epoch: nil,
            samples: [sample(0.98, entropy: 6.0, replicators: 0, copy_rate: 0.0, tapes: 1_600, top_share: 0.01),
                      sample(0.95, entropy: 5.5, replicators: 2, copy_rate: 0.0008, tapes: 1_500, top_share: 0.03),
                      sample(0.96, entropy: 5.8, replicators: 1, copy_rate: 0.0004, tapes: 1_550, top_share: 0.02)])
  end

  it "reads the swept parameter values of every sampled run" do
    expect(report.rows.map(&:params)).to all(eq("mutation_rate" => 0.000244))
  end

  it "reports the stored transition epoch and the bare threshold crossing of a true positive" do
    expect(row_for(true_positive)).to have_attributes(transition_epoch: 200, collapse_epoch: 200)
  end

  it "reports the entropy minimum of a true positive and the epoch it fell on" do
    expect(row_for(true_positive)).to have_attributes(min_entropy_bits: 2.0, min_entropy_epoch: 300)
  end

  it "reports the replicator peak of a true positive, its epoch and the first count above zero" do
    expect(row_for(true_positive)).to have_attributes(peak_replicator_count: 9, peak_replicator_epoch: 300,
                                                      first_replicator_epoch: 200)
  end

  it "reports the copy rate peak of a true positive and its epoch" do
    expect(row_for(true_positive)).to have_attributes(peak_copy_rate: 0.005, peak_copy_rate_epoch: 300)
  end

  it "reports the last sample of a true positive" do
    expect(row_for(true_positive)).to have_attributes(final_compress_ratio: 0.4, final_distinct_tapes: 120,
                                                      final_top_share: 0.41)
  end

  it "reads a flagged run whose replicator census never moved" do
    expect(row_for(entropy_only)).to have_attributes(transition_epoch: 100, collapse_epoch: 100,
                                                     min_entropy_bits: 1.0, peak_replicator_count: 0,
                                                     peak_replicator_epoch: nil, first_replicator_epoch: nil,
                                                     peak_copy_rate: 0.0001)
  end

  it "reads a replicating run the detector never flagged" do
    expect(row_for(replicator_only)).to have_attributes(transition_epoch: nil, collapse_epoch: nil,
                                                        peak_replicator_count: 2, peak_replicator_epoch: 200,
                                                        first_replicator_epoch: 200)
  end

  it "counts the runs of an arm, its flags, its replicators and the runs holding both" do
    expect(report.arms.sole).to have_attributes(runs: 3, flagged: 2, replicated: 2, both: 1)
  end

  it "counts the runs the two observables disagree on" do
    expect(report.arms.sole.either_but_not_both).to eq(2)
  end

  it "names the arm the way the sweep's phase diagram does" do
    expect(report.arms.sole.label).to eq("0.000244")
  end

  context "with a crossing the detector never settled on" do
    let!(:flicker) do
      sampled(transition_epoch: nil,
              samples: [sample(0.8, entropy: 5.0, replicators: 0, copy_rate: 0.0, tapes: 800, top_share: 0.05),
                        sample(0.5, entropy: 4.0, replicators: 0, copy_rate: 0.0, tapes: 500, top_share: 0.12),
                        sample(0.85, entropy: 5.2, replicators: 0, copy_rate: 0.0, tapes: 850, top_share: 0.04)])
    end

    it "reports the bare crossing of a run the detector left unflagged" do
      expect(row_for(flicker)).to have_attributes(transition_epoch: nil, collapse_epoch: 200)
    end

    it "leaves the unsettled run out of both counts of its arm" do
      expect(report.arms.sole).to have_attributes(runs: 4, flagged: 2, replicated: 2, either_but_not_both: 2)
    end
  end

  context "with a run nothing has been sampled from" do
    before { create(:run, experiment: experiment) }

    it "leaves the unsampled run out of the report" do
      expect(report.rows.size).to eq(3)
    end
  end

  describe "#to_text" do
    it "aligns a header and one line per run over the fixed columns" do
      lines = report.to_text.lines.map(&:strip)

      expect(lines.first).to match(/\Arun_id\s+seed\s+mutation_rate\s+transition_epoch\s+collapse_epoch/)
    end

    it "prints an em dash where an observable never moved" do
      expect(report.to_text).to include("—")
    end

    it "prints the arm summary under the runs" do
      expect(report.to_text).to include("either_but_not_both")
    end
  end

  describe "#to_csv" do
    it "writes the run rows under the run header" do
      table = CSV.parse(report.to_csv)

      expect(table[1].first(2)).to eq([true_positive.id.to_s, true_positive.seed.to_s])
    end

    it "heads the arm summary with the columns the published report promises" do
      table = CSV.parse(report.to_csv)

      expect(table[-2]).to eq(%w[arm n flagged replicators both either_but_not_both])
    end

    it "writes the arm summary as a second section" do
      table = CSV.parse(report.to_csv)

      expect(table.last).to eq(["0.000244", "3", "2", "2", "1", "2"])
    end
  end

  def row_for(run) = report.rows.find { |row| row.run_id == run.id }

  def sampled(transition_epoch:, samples:)
    run = create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch,
                       params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.000244))
    samples.each_with_index { |values, index| create(:sample, run: run, epoch: (index + 1) * 100, values: values) }
    run
  end

  def sample(compress_ratio, entropy:, replicators:, copy_rate:, tapes:, top_share:)
    { "compress_ratio" => compress_ratio, "distinct_tapes" => tapes, "top_share" => top_share,
      "op_density" => 0.1, "replicator_count" => replicators, "entropy_bits" => entropy,
      "copy_rate" => copy_rate }
  end
end
