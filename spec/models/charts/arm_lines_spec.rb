# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::ArmLines do
  def arm(label, points) = Charts::ArmLines::Arm.new(label: label, points: points)

  def build(arms)
    described_class.new(arms: arms, title: "Distinct lineages vs epoch", y_label: "Distinct lineages")
  end

  describe "#lines" do
    it "draws one line per sampled arm, each with its own dash" do
      chart = build([arm("0", [[0, 4], [100, 8]]), arm("2048", [[0, 2], [100, 3]])])

      expect(chart.lines.map(&:label)).to eq(%w[0 2048])
      expect(chart.lines.map(&:dash).uniq.size).to eq(2)
    end

    it "draws the points in epoch order" do
      chart = build([arm("0", [[100, 8], [0, 4]])])

      expect(chart.lines.first.path)
        .to eq("M#{chart.x_pixel(0).round(2)},#{chart.y_pixel(4).round(2)} " \
               "L#{chart.x_pixel(100).round(2)},#{chart.y_pixel(8).round(2)}")
    end

    context "with an arm nothing was sampled from" do
      it "draws no line for it" do
        chart = build([arm("0", []), arm("2048", [[0, 2]])])

        expect(chart.lines.map(&:label)).to eq(["2048"])
      end
    end
  end

  describe "#y_scale" do
    it "anchors the axis at zero and spans every arm" do
      chart = build([arm("0", [[0, 4]]), arm("2048", [[0, 40]])])

      expect(chart.y_scale.min).to eq(0.0)
      expect(chart.y_scale.max).to be >= 40
    end
  end

  describe "#empty?" do
    context "with no sampled arm" do
      it "reports the chart as empty" do
        expect(build([arm("0", []), arm("2048", [])])).to be_empty
      end
    end

    context "with one sampled arm" do
      it "reports the chart as drawable" do
        expect(build([arm("0", []), arm("2048", [[0, 1]])])).not_to be_empty
      end
    end
  end
end
