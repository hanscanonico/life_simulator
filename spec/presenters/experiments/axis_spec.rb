# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::Axis do
  describe "#label_of" do
    it "names a numeric value the way the charts do" do
      axis = described_class.new(name: "mutation_rate", values: [0.0, 0.5])

      expect(axis.label_of(0.5)).to eq(Charts.format_value(0.5))
    end

    it "joins a paired value with a times sign" do
      axis = described_class.new(name: "world_size", values: [{ "width" => 32, "height" => 32 }])

      expect(axis.label_of("width" => 32, "height" => 32)).to eq("32")
    end

    it "calls the radius sweep's zero arm well-mixed" do
      axis = described_class.new(name: "radius", values: [1, 2, 4, 0])

      expect(axis.label_of(0)).to eq("well-mixed")
    end

    it "keeps a zero that is not a radius numeric" do
      axis = described_class.new(name: "mutation_rate", values: [0.0, 0.5])

      expect(axis.label_of(0.0)).to eq(Charts.format_value(0.0))
    end
  end

  describe "#position_of" do
    subject(:axis) { described_class.new(name: "radius", values: [1, 2, 4, 0]) }

    it "plots the well-mixed arm past the widest neighbourhood" do
      expect(axis.position_of(0)).to be > axis.position_of(4)
    end

    it "leaves the ordinary radii at their own value" do
      expect(axis.values.take(3).map { |radius| axis.position_of(radius) }).to eq([1.0, 2.0, 4.0])
    end
  end

  describe "#log?" do
    it "keeps the radius sweep on a linear axis" do
      axis = described_class.new(name: "radius", values: [1, 2, 4, 0])

      expect(axis.log?).to be(false)
    end

    it "leaves the well-mixed arm out of the span it measures" do
      axis = described_class.new(name: "radius", values: [1, 60, 0])

      expect(axis.position_of(0) / axis.position_of(1)).to be > 100
      expect(axis.log?).to be(false)
    end

    it "holds for a grid spanning more than two decades" do
      axis = described_class.new(name: "mutation_rate", values: [0.0, 2.0**-16, 2.0**-8])

      expect(axis.log?).to be(true)
    end
  end
end
