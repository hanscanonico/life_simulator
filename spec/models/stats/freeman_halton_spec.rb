# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::FreemanHalton do
  it "agrees with Fisher's exact test on two rows" do
    expect(described_class.p_value([[1, 9], [11, 3]]))
      .to be_within(1e-12).of(Stats::FisherExact.two_sided([[1, 9], [11, 3]]))
  end

  it "reads the lineage-diversity sweep's emergence by reach" do
    expect(described_class.p_value([[3, 87], [16, 74], [9, 81], [4, 86]])).to be_within(1e-9).of(0.003_079_806_918)
  end

  context "with every row carrying the same counts" do
    it "reads p as 1" do
      expect(described_class.p_value([[2, 8], [2, 8], [2, 8]])).to eq(1.0)
    end
  end

  context "with nothing in the first column" do
    it "reads p as 1, the only table those margins allow" do
      expect(described_class.p_value([[0, 10], [0, 10], [0, 10]])).to eq(1.0)
    end
  end

  context "with an empty row" do
    it "declines the test" do
      expect(described_class.p_value([[1, 9], [0, 0], [2, 8]])).to be_nil
    end
  end

  context "with a single row" do
    it "declines the test" do
      expect(described_class.p_value([[1, 9]])).to be_nil
    end
  end
end
