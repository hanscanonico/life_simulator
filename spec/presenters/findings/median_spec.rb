# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::Median do
  it "takes the lower of the middle pair of an even count rather than interpolating" do
    expect(described_class.of([1, 2, 3, 10])).to eq(2)
  end

  it "takes the middle of an odd count" do
    expect(described_class.of([10, 1, 3])).to eq(3)
  end

  it "sorts what it is given" do
    expect(described_class.of([9, 1, 5, 2, 7])).to eq(5)
  end

  it "has no median for nothing" do
    expect(described_class.of([])).to be_nil
  end
end
