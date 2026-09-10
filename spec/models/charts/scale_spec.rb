# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::Scale do
  describe "#position" do
    it "maps the bounds onto the ends of the axis" do
      scale = described_class.new(values: [0, 10], length: 100)

      expect([scale.position(0), scale.position(5), scale.position(10)]).to eq([0.0, 50.0, 100.0])
    end

    it "runs the axis backwards" do
      scale = described_class.new(values: [0, 10], length: 100, flip: true)

      expect([scale.position(0), scale.position(10)]).to eq([100.0, 0.0])
    end

    it "clamps values outside the bounds" do
      scale = described_class.new(values: [0, 10], length: 100)

      expect([scale.position(-5), scale.position(50)]).to eq([0.0, 100.0])
    end

    context "with a log axis" do
      it "spaces decades evenly" do
        scale = described_class.new(values: [1, 1000], length: 90, log: true)

        expect([scale.position(1), scale.position(10), scale.position(100)]).to eq([0.0, 30.0, 60.0])
      end

      it "parks a non-positive value one decade below the smallest positive one" do
        scale = described_class.new(values: [0, 0.01, 1], length: 90, log: true)

        expect([scale.position(0), scale.position(0.01), scale.position(1)]).to eq([0.0, 30.0, 90.0])
      end

      it "falls back to a linear axis with no positive value" do
        scale = described_class.new(values: [0, -1], length: 100, log: true)

        expect(scale).not_to be_log
      end
    end

    context "with a single value" do
      it "pads the bounds so the axis has a span" do
        scale = described_class.new(values: [5], length: 100)

        expect(scale.position(5)).to eq(50.0)
      end
    end

    context "with no values" do
      it "still produces a usable axis" do
        scale = described_class.new(values: [], length: 100)

        expect([scale.min, scale.max, scale.position(0)]).to eq([0.0, 1.0, 0.0])
      end
    end

    context "with a flat zero series" do
      it "runs the axis from zero up to one" do
        scale = described_class.new(values: [0, 0, 0], length: 100)

        expect(scale).to have_attributes(min: 0.0, max: 1.0)
      end
    end
  end

  describe "#ticks" do
    it "picks round values inside the bounds" do
      ticks = described_class.new(values: [0, 100], length: 100).ticks

      expect(ticks.map(&:value)).to eq([0.0, 20.0, 40.0, 60.0, 80.0, 100.0])
    end

    it "rounds a step that would otherwise land on ragged values" do
      ticks = described_class.new(values: [0, 7], length: 100).ticks

      expect(ticks.map(&:label)).to eq(%w[0 2 4 6 8])
    end

    it "extends the bounds to the ticks that enclose the values" do
      scale = described_class.new(values: [0, 16_384], length: 100)

      expect(scale).to have_attributes(min: 0.0, max: 20_000.0)
      expect(scale.ticks.map(&:label)).to eq(%w[0 5000 10000 15000 20000])
    end

    it "extends a negative lower bound down to the tick below it" do
      scale = described_class.new(values: [-3, 42], length: 100)

      expect(scale).to have_attributes(min: -10.0, max: 50.0)
    end

    it "labels ticks through the shared formatter" do
      ticks = described_class.new(values: [0, 1], length: 100).ticks

      expect(ticks.map(&:label)).to eq(%w[0 0.2 0.4 0.6 0.8 1])
    end

    it "puts a tick on every decade of a log axis" do
      ticks = described_class.new(values: [0.001, 10], length: 100, log: true).ticks

      expect(ticks.map(&:label)).to eq(%w[0.001 0.01 0.1 1 10])
    end

    it "gives the zero slot its own tick" do
      ticks = described_class.new(values: [0, 0.01, 1], length: 100, log: true).ticks

      expect(ticks.map(&:label)).to eq(%w[0 0.01 0.1 1])
    end
  end
end
