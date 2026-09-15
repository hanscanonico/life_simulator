# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::FisherExact do
  it "reproduces the lady tasting tea, which is the test's own worked example" do
    expect(described_class.two_sided([[3, 1], [1, 3]])).to be_within(1e-12).of(17.0 / 35)
  end

  it "reads an arm that emerged once against one that emerged three times" do
    expect(described_class.two_sided([[1, 9], [3, 7]])).to be_within(1e-9).of(0.582_043_343_653)
  end

  it "reads a table the counts do separate" do
    expect(described_class.two_sided([[1, 9], [11, 3]])).to be_within(1e-9).of(0.002_759_456_185)
  end

  it "reads a perfectly separated table as far below the threshold" do
    expect(described_class.two_sided([[10, 0], [0, 10]])).to be_within(1e-9).of(0.000_010_825_088)
  end

  it "gives the same p-value for a table and its transpose" do
    expect(described_class.two_sided([[2, 8], [0, 10]]))
      .to eq(described_class.two_sided([[2, 0], [8, 10]]))
  end

  context "with the two rows carrying identical counts" do
    it "reads p as 1" do
      expect(described_class.two_sided([[5, 5], [5, 5]])).to eq(1.0)
    end
  end

  context "with nothing emerging in either row" do
    it "reads p as 1, the only table those margins allow" do
      expect(described_class.two_sided([[0, 10], [0, 10]])).to eq(1.0)
    end
  end

  context "with an empty row" do
    it "declines the test rather than returning a number" do
      expect(described_class.two_sided([[0, 0], [2, 8]])).to be_nil
      expect(described_class.two_sided([[2, 8], [0, 0]])).to be_nil
    end
  end
end
