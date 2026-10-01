# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::ReachCap128Reading::Comparison do
  subject(:comparison) { described_class.new(treatment: reach_arm("radius 4", *treatment), control: control_arm) }

  let(:control_arm) { reach_arm("control, radius 1", 11, 270) }

  context "with a radius 4 arm well above the control" do
    let(:treatment) { [21, 270] }

    it "is shown" do
      expect(comparison.outcome).to eq(:shown)
    end
  end

  context "with radius 4 above the control short of the level" do
    let(:treatment) { [20, 270] }

    it "is not shown" do
      expect(comparison.outcome).to eq(:not_shown)
    end
  end

  context "with radius 4 at the control's rate" do
    let(:treatment) { [11, 270] }

    it "is refuted" do
      expect(comparison.outcome).to eq(:refuted)
    end
  end

  context "with radius 4 below the control" do
    let(:treatment) { [3, 270] }

    it "is refuted" do
      expect([comparison.outcome, comparison.outcome_label, comparison.badge_class])
        .to eq([:refuted, "refuted", "badge-error"])
    end
  end

  context "with no counted run at radius 4" do
    let(:treatment) { [0, 0] }

    it "is not yet tested" do
      expect([comparison.outcome, comparison.p_value]).to eq([:untested, nil])
      expect(comparison.line).to eq("H-reach128 not yet tested: an arm has no counted run")
    end
  end

  # Margins 3 and 3, 3 emerged in all: P(X >= 2) = (C(3,2)·C(3,1) + C(3,3)·C(3,0)) / C(6,3)
  # = (9 + 1) / 20.
  context "with a table small enough to sum by hand" do
    subject(:comparison) { described_class.new(treatment: reach_arm("radius 4", 2, 3), control: reach_arm("c", 1, 3)) }

    it "reads the one-sided Fisher p exactly" do
      expect(comparison.p_value).to eq(Rational(1, 2))
      expect(comparison.outcome).to eq(:not_shown)
    end

    it "states the counts and the p" do
      expect(comparison.line).to eq("H-reach128 not shown; radius 4 2/3 against c 1/3: one-sided Fisher p = 0.50000")
    end
  end
end
