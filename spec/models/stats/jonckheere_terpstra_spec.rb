# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::JonckheereTerpstra do
  def p_value(groups, permutations: 10_000, seed: Lab::LineageDiversityReading::PERMUTATION_SEED)
    described_class.new(groups).p_value(permutations: permutations, random: Random.new(seed))
  end

  describe "#statistic" do
    # Group 0 against 1: 1<2, 1<3, 2=2 (one half), 2<3; 0 against 2: 1<4, 2<4; 1 against 2:
    # 2<4, 3<4. That is 3.5 + 2 + 2.
    it "counts the pairs where the later group reads higher, a tie one half" do
      expect(described_class.new([[1, 2], [2, 3], [4]]).statistic).to eq(Rational(15, 2))
    end

    it "counts nothing for a group read against itself" do
      expect(described_class.new([[5, 1, 3], []]).statistic).to eq(0)
    end

    it "reads a tie across every group as one half a pair" do
      expect(described_class.new([[1.0, 1.0], [1.0], [1.0]]).statistic).to eq(Rational(5, 2))
    end
  end

  describe "#p_value" do
    let(:ordered) { [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]] }

    it "is the same on every call" do
      expect(p_value(ordered.map(&:reverse))).to eq(p_value(ordered.map(&:reverse)))
    end

    it "moves with the generator's seed" do
      groups = [[1, 2, 7], [3, 4, 8], [5, 6, 9]]

      expect(p_value(groups, seed: 1)).not_to eq(p_value(groups, seed: 2))
    end

    it "reads a perfectly ordered sample as far below any level" do
      expect(p_value(ordered)).to eq(Rational(1, 10_001))
    end

    it "reads a reversed sample as 1" do
      expect(p_value(ordered.reverse)).to eq(1)
    end

    # The record's own case: at three values in each of three groups, 21 reads an exact p of
    # 0.061 where the normal approximation reads 0.048.
    it "estimates the exact p of the record's three-by-three case" do
      groups = [[1, 2, 7], [3, 4, 8], [5, 6, 9]]

      expect(described_class.new(groups).statistic).to eq(21)
      expect(p_value(groups, permutations: Lab::LineageDiversityReading::PERMUTATIONS).to_f).to be_within(0.003).of(0.061)
    end
  end
end
