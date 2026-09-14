# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ArmSeries do
  let(:experiment) { create(:experiment, param_grid: { "energy_per_epoch" => [0, 2048] }) }
  let(:axis) { Experiments::Axis.sweep(experiment.param_grid).first }
  let(:free_run) { create(:run, experiment: experiment, params: { "energy_per_epoch" => 0 }) }
  let(:priced_run) { create(:run, experiment: experiment, params: { "energy_per_epoch" => 2048 }) }

  def series_for(runs) = described_class.build(axis: axis, runs: runs)

  describe "#lineage_charts" do
    it "averages an arm's runs at every epoch they were sampled" do
      create(:sample, run: free_run, epoch: 100, values: { "distinct_lineages" => 10 })
      other = create(:run, experiment: experiment, params: { "energy_per_epoch" => 0 })
      create(:sample, run: other, epoch: 100, values: { "distinct_lineages" => 20 })

      chart = series_for([free_run, other]).lineage_charts.first

      expect(chart.arms.first).to have_attributes(label: "0", points: [[100.0, 15.0]])
    end

    it "titles the chart by the observable and the axis it is read across" do
      create(:sample, run: priced_run, epoch: 100, values: { "distinct_lineages" => 3 })

      expect(series_for([priced_run]).lineage_charts.map(&:title))
        .to eq(["Distinct lineages vs epoch, per arm of energy per epoch"])
    end

    context "with samples that carry no lineage reading" do
      it "draws nothing" do
        create(:sample, run: free_run, epoch: 100, values: { "compress_ratio" => 0.4 })

        expect(series_for([free_run]).lineage_charts).to be_empty
      end
    end
  end

  describe "#complexity_charts" do
    it "keeps the two complexity observables apart" do
      create(:sample, run: priced_run, epoch: 200,
                      values: { "dominant_compressed_len" => 32, "dominant_instruction_count" => 700 })

      charts = series_for([priced_run]).complexity_charts

      expect(charts.map { |chart| chart.arms.last.points }).to eq([[[200.0, 32.0]], [[200.0, 700.0]]])
    end

    # A sample the engine reported no replicator for carries a null length, which is a
    # reading the mean must not take for a zero.
    context "with a sample whose complexity was never measured" do
      it "leaves that epoch out of the arm's line" do
        create(:sample, run: priced_run, epoch: 100,
                        values: { "dominant_compressed_len" => nil, "dominant_instruction_count" => nil })
        create(:sample, run: priced_run, epoch: 200,
                        values: { "dominant_compressed_len" => 32, "dominant_instruction_count" => 700 })

        expect(series_for([priced_run]).complexity_charts.first.arms.last.points).to eq([[200.0, 32.0]])
      end
    end
  end

  describe "#any?" do
    context "with no samples at all" do
      it "reports the sweep as having no series to show" do
        expect(series_for([free_run, priced_run])).not_to be_any
      end
    end
  end
end
