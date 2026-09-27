# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::LocalityEmergenceReading::Peak do
  subject(:peak) do
    described_class.new(arms: [locality_arm(1, radius_one, 90), locality_arm(4, radius_four, 90),
                               locality_arm(0, well_mixed, 90)])
  end

  context "with sweep 12's exploratory counts" do
    let(:radius_one) { 4 }
    let(:radius_four) { 16 }
    let(:well_mixed) { 3 }

    it "is shown, both corrected p below the family level" do
      expect(peak.outcome).to eq(:shown)
      expect(peak.adjusted_p_values.map(&:to_f)).to all(be < 0.05)
    end

    it "tests radius 4 against radius 1, then against well-mixed" do
      expect(peak.p_values).to eq([Stats::FisherExact.greater([[16, 74], [4, 86]]),
                                   Stats::FisherExact.greater([[16, 74], [3, 87]])])
    end
  end

  context "with radius 4 at most as often as both rivals" do
    let(:radius_one) { 9 }
    let(:radius_four) { 4 }
    let(:well_mixed) { 4 }

    it "is refuted" do
      expect(peak.outcome).to eq(:refuted)
    end
  end

  context "with radius 4 ahead of both, but not by enough" do
    let(:radius_one) { 4 }
    let(:radius_four) { 6 }
    let(:well_mixed) { 3 }

    it "is not shown" do
      expect(peak.outcome).to eq(:not_shown)
    end
  end

  context "with both raw p below the level and the Holm correction lifting one above it" do
    let(:radius_one) { 3 }
    let(:radius_four) { 10 }
    let(:well_mixed) { 3 }

    it "is not shown" do
      expect(peak.p_values.map(&:to_f)).to all(be < 0.05)
      expect(peak.outcome).to eq(:not_shown)
    end
  end

  context "with radius 4 ahead of one rival and behind the other" do
    let(:radius_one) { 20 }
    let(:radius_four) { 16 }
    let(:well_mixed) { 3 }

    it "is not shown rather than refuted" do
      expect(peak.outcome).to eq(:not_shown)
    end
  end

  context "with an arm that has not finished a run" do
    subject(:peak) { described_class.new(arms: [locality_arm(1, 4, 90), locality_arm(4, 16, 90)]) }

    it "is not yet tested" do
      expect(peak.outcome).to eq(:untested)
      expect(peak.line).to start_with("H-peak not yet tested")
    end
  end
end
