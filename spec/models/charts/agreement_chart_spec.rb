# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::AgreementChart do
  def arm(label, runs: 5, flagged: 0, replicated: 0, both: 0)
    Experiments::TransitionArmsService::Arm.new(label: label, runs: runs, flagged: flagged,
                                                replicated: replicated, both: both)
  end

  def build(arms) = described_class.new(arms: arms, title: "Detector against replicator census, per arm")

  describe "#bars" do
    subject(:chart) do
      build([arm("1", flagged: 5, replicated: 3, both: 2), arm("2", flagged: 1, replicated: 1, both: 1)])
    end

    # Two arms split the 668-unit axis into bands of 334; the bars take 78% of a band,
    # centred in it, so a band's three bars are 86.84 wide and start 36.74 units in.
    it "lines the three bars of an arm up inside its band" do
      expect(chart.bars.first(3).map { |bar| bar.x.round(2) }).to eq([156.74, 243.58, 330.42])
      expect(chart.bars.first(3).map { |bar| bar.width.round(2) }).to eq([86.84] * 3)
    end

    it "places the second arm's bars a band further along" do
      expect(chart.bars[3].x.round(2)).to eq(490.74)
    end

    # The tallest bar is the three flagged-only runs of the first arm, so the y axis runs
    # 0..3 over the 240-unit plot: three runs fill it, two take two thirds, one a third.
    it "draws a bar as tall as its count against the tallest bar anywhere" do
      heights = chart.bars.first(3).map { |bar| bar.height.round(2) }

      expect(heights).to eq([240.0, 80.0, 160.0])
      expect(chart.bars.first.y.round(2)).to eq(24.0)
    end

    it "names the arm, the series and the count in each bar's title" do
      expect(chart.bars.first.label).to eq("1 — flagged only: 3 of 5 sampled runs")
    end

    it "splits an arm's runs into the two disagreements and the agreement" do
      counts = chart.bars.first(3).map { |bar| bar.label[/: (\d+)/, 1].to_i }

      expect(counts).to eq([3, 1, 2])
    end
  end

  describe "#empty?" do
    context "with no arm at all" do
      it "draws nothing" do
        chart = build([])

        expect(chart).to be_empty
        expect(chart.bars).to eq([])
        expect(chart.x_ticks).to eq([])
      end
    end

    context "with arms that were never flagged and never replicated" do
      it "draws nothing" do
        expect(build([arm("1"), arm("2")])).to be_empty
      end
    end

    context "with an arm where the two observables agree" do
      it "still draws the chart" do
        expect(build([arm("1", flagged: 2, replicated: 2, both: 2)])).not_to be_empty
      end
    end
  end

  describe "#y_ticks" do
    it "counts runs in whole numbers" do
      chart = build([arm("1", flagged: 1, replicated: 1, both: 1)])

      expect(chart.y_ticks.map(&:label)).to eq(%w[0 1])
    end

    it "keeps the nice steps of a taller axis" do
      chart = build([arm("1", flagged: 3, replicated: 3)])

      expect(chart.y_ticks.map(&:label)).to eq(%w[0 1 2 3])
    end
  end

  describe "#x_ticks" do
    it "names every arm, each on the centre of its band" do
      chart = build([arm("1", flagged: 1), arm("2", flagged: 1)])

      expect(chart.x_ticks.map(&:label)).to eq(%w[1 2])
      expect(chart.x_ticks.map { |tick| tick.position.round(2) }).to eq([287.0, 621.0])
    end

    context "with more arms than can be labelled" do
      it "names every second arm, starting from the first" do
        chart = build((1..10).map { |value| arm(value.to_s, flagged: 1) })

        expect(chart.x_ticks.map(&:label)).to eq(%w[1 3 5 7 9])
      end
    end
  end

  describe "#x_tick_anchor" do
    subject(:chart) { build([arm("1", flagged: 1)]) }

    it "hangs a label near an end off that end and centres the rest" do
      positions = [chart.plot_left + 20, (chart.plot_left + chart.plot_right) / 2, chart.plot_right - 20]

      expect(positions.map { |position| chart.x_tick_anchor(position) }).to eq(%w[start middle end])
    end
  end

  describe "#x_tick_label_x" do
    subject(:chart) { build([arm("1", flagged: 1)]) }

    it "keeps a label off the edges without moving the ones with room" do
      middle = (chart.plot_left + chart.plot_right) / 2
      positions = [chart.plot_left, middle, chart.plot_right].map { |x| chart.x_tick_label_x(x) }

      expect(positions).to eq([chart.plot_left + Charts::Plot::EDGE_INSET, middle,
                               chart.plot_right - Charts::Plot::EDGE_INSET])
    end
  end
end
