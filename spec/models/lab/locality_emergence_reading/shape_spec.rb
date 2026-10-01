# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::LocalityEmergenceReading::Shape do
  subject(:shape) { described_class.read(arms) }

  def arms_of(counts) = counts.map { |radius, emerged| locality_arm(radius, emerged, 90) }

  context "with a set that peaks at radius 4" do
    let(:arms) { arms_of(1 => 4, 2 => 9, 3 => 14, 4 => 16, 6 => 12, 8 => 6, 0 => 3) }

    it "is shown, with the fitted peak" do
      expect(shape.outcome).to eq(:shown)
      expect(shape.peak).to be_within(0.01).of(4.59)
    end

    it "leaves well-mixed out of the fit and reports it beside it" do
      expect(shape.groups.map(&:first)).to eq([1, 2, 3, 4, 6, 8])
      expect(shape.line).to include("well-mixed, not fitted: 3/90")
    end
  end

  context "with a flat set" do
    let(:arms) { arms_of(1 => 10, 2 => 10, 3 => 10, 4 => 10, 6 => 10, 8 => 10) }

    it "is not shown" do
      expect(shape.outcome).to eq(:not_shown)
    end
  end

  context "with a set that rises across the radii" do
    let(:arms) { arms_of(1 => 2, 2 => 5, 3 => 8, 4 => 12, 6 => 20, 8 => 30) }

    it "is not shown" do
      expect(shape.outcome).to eq(:not_shown)
    end
  end

  context "with a set whose downward curve peaks beyond the radii" do
    let(:arms) { arms_of(1 => 5, 2 => 15, 3 => 25, 4 => 34, 6 => 50, 8 => 62) }

    it "is not shown" do
      expect(shape.fit.quadratic).to be_negative
      expect(shape.peak).to be > 8
      expect(shape.outcome).to eq(:not_shown)
    end
  end

  context "with a set that rises across the radii, flattening, its vertex just inside radius 8" do
    let(:arms) { arms_of(1 => 1, 2 => 2, 3 => 5, 4 => 9, 6 => 20, 8 => 22) }

    it "is not shown, though the curvature is significant" do
      expect(shape.fit.quadratic).to be_negative
      expect(shape.fit.wald_p).to be < 0.05
      expect(shape.peak).to be_between(6, 8).exclusive
      expect(shape.outcome).to eq(:not_shown)
    end
  end

  context "with a set that falls across the radii, steepening, its vertex just inside radius 1" do
    let(:arms) { arms_of(1 => 40, 2 => 38, 3 => 35, 4 => 30, 6 => 18, 8 => 4) }

    it "is not shown, though the curvature is significant" do
      expect(shape.fit.quadratic).to be_negative
      expect(shape.fit.wald_p).to be < 0.05
      expect(shape.peak).to be_between(1, 2).exclusive
      expect(shape.outcome).to eq(:not_shown)
    end
  end

  context "with fewer than three finite radii finished" do
    let(:arms) { arms_of(1 => 4, 4 => 16, 0 => 3) }

    it "is not yet tested" do
      expect(shape.outcome).to eq(:untested)
      expect(shape.fit).to be_nil
    end
  end

  context "with nothing emerged" do
    let(:arms) { arms_of(1 => 0, 2 => 0, 4 => 0) }

    it "is not yet tested" do
      expect(shape.outcome).to eq(:untested)
    end
  end
end
