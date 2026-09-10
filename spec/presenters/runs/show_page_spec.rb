# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::ShowPage do
  subject(:page) { described_class.build(run: run) }

  let(:run) { create(:run, epochs: 1_000, epochs_done: 250, transition_epoch: 200) }

  describe "#charts" do
    context "with no sample" do
      it "draws every metric as an empty chart" do
        expect(page.charts).to all(be_empty)
      end
    end

    it "draws one chart per DESIGN observable" do
      expect(page.charts.map(&:title)).to eq(described_class::METRICS.values)
    end

    it "plots the samples of a metric in epoch order" do
      create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      chart = page.charts.first

      expect(chart).not_to be_empty
      expect(chart.marker_pixel).to eq(chart.plot_right.to_f)
    end

    it "skips a metric a sample does not carry" do
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      expect(page.charts.last).to be_empty
    end
  end

  describe "#snapshots" do
    it "keeps only the snapshots with a rendered PNG, in epoch order" do
      late = create(:snapshot, run: run, epoch: 300)
      early = create(:snapshot, run: run, epoch: 100)
      create(:snapshot, run: run, epoch: 200, png: nil)

      expect(page.snapshots.map(&:id)).to eq([early.id, late.id])
    end
  end

  describe "#params" do
    it "sorts the parameters so two runs read the same way" do
      expect(page.params.keys).to eq(run.params.keys.sort)
    end
  end

  describe "#progress" do
    it "is the share of epochs done" do
      expect(page.progress).to eq(25.0)
    end
  end
end
