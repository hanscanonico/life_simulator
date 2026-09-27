# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::Holm do
  it "multiplies the smallest of m p-values by m and the next by m − 1, in the order given" do
    expect(described_class.adjust([Rational(4, 100), Rational(1, 100)])).to eq([Rational(4, 100), Rational(2, 100)])
  end

  it "never lets a larger p adjust below a smaller one's adjusted value" do
    expect(described_class.adjust([Rational(3, 100), Rational(4, 100)])).to eq([Rational(6, 100), Rational(6, 100)])
  end

  it "caps an adjusted p at 1" do
    expect(described_class.adjust([0.6, 0.7])).to eq([1, 1])
  end

  it "leaves a single test as it is" do
    expect(described_class.adjust([0.03])).to eq([0.03])
  end
end
