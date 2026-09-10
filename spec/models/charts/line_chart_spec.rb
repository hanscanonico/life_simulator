# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::LineChart do
  def build(points, **options)
    described_class.new(points: points, title: "Compression ratio", x_label: "Epoch",
                        y_label: "Ratio", **options)
  end

  describe "#path" do
    it "draws one segment per point, in epoch order" do
      chart = build([[200, 0.5], [0, 1.0]])

      expect(chart.path).to start_with("M").and include(" L")
      expect(chart.path.scan(/[ML]([\d.]+),/).flatten.map(&:to_f)).to eq([chart.x_pixel(0), chart.x_pixel(200)])
    end

    it "puts the first and the last point on the ends of the x axis" do
      chart = build([[0, 1.0], [100, 0.4]])

      expect([chart.x_pixel(0), chart.x_pixel(100)]).to eq([chart.plot_left.to_f, chart.plot_right.to_f])
    end
  end

  describe "#empty?" do
    context "with no points" do
      it "reports the chart as empty" do
        expect(build([])).to be_empty
      end
    end

    context "with points" do
      it "reports the chart as drawable" do
        expect(build([[0, 1.0]])).not_to be_empty
      end
    end
  end

  describe "#marker_pixel" do
    it "places the marker on the x axis" do
      chart = build([[0, 1.0], [100, 0.4]], marker: 50)

      expect(chart.marker_pixel).to eq(chart.plot_left + (chart.plot_width / 2.0))
    end

    context "with a marker outside the sampled range" do
      it "draws no marker" do
        expect(build([[0, 1.0], [100, 0.4]], marker: 900).marker_pixel).to be_nil
      end
    end

    context "with no marker" do
      it "draws no marker" do
        expect(build([[0, 1.0]]).marker_pixel).to be_nil
      end
    end
  end

  describe "#y_scale" do
    it "anchors the y axis at zero so series are comparable" do
      expect(build([[0, 0.8], [1, 0.9]]).y_scale.min).to eq(0.0)
    end
  end
end
