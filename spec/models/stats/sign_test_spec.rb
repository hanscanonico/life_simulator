# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::SignTest do
  it "sums the upper binomial tail exactly: 6 of 6 pairs is 1/64" do
    expect(described_class.one_sided(favouring: 6, against: 0)).to eq(Rational(1, 64))
  end

  it "reads 5 of 6 as 7/64, short of 0.05" do
    expect(described_class.one_sided(favouring: 5, against: 1)).to eq(Rational(7, 64))
  end

  it "reads 8 of 9 as 10/512" do
    expect(described_class.one_sided(favouring: 8, against: 1)).to eq(Rational(10, 512))
  end

  it "reads a pair favouring neither way as the whole distribution" do
    expect(described_class.one_sided(favouring: 0, against: 3)).to eq(1)
  end

  context "with no discordant pair" do
    it "tests nothing" do
      expect(described_class.one_sided(favouring: 0, against: 0)).to be_nil
    end
  end
end
