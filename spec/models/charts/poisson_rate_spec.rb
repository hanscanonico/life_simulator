# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::PoissonRate do
  describe "#value" do
    it "is the events over the exposure" do
      expect(described_class.new(events: 3, exposure: 22).value).to be_within(1e-12).of(3 / 22.0)
    end

    it "has no rate without exposure" do
      rate = described_class.new(events: 0, exposure: 0)

      expect(rate).to have_attributes(value: nil, lower: nil, upper: nil)
    end
  end

  # The textbook exact bounds for a Poisson count of 3 are chi-square quantiles:
  # chi2(0.025, 6) / 2 = 0.6186 and chi2(0.975, 8) / 2 = 8.7673.
  describe "#lower and #upper" do
    it "inverts the Poisson distribution at the 95% level" do
      rate = described_class.new(events: 3, exposure: 1)

      expect(rate.lower).to be_within(1e-3).of(0.6186)
      expect(rate.upper).to be_within(1e-3).of(8.7673)
    end

    it "brackets the estimate" do
      rate = described_class.new(events: 12, exposure: 4)

      expect(rate.lower).to be < rate.value
      expect(rate.upper).to be > rate.value
    end

    context "with no event at all" do
      it "is one-sided, and still finite" do
        rate = described_class.new(events: 0, exposure: 2)

        expect(rate.lower).to eq(0.0)
        expect(rate.upper).to be_within(1e-3).of(3.6889 / 2)
      end
    end

    it "narrows as the exposure grows at a constant rate" do
      narrow = described_class.new(events: 400, exposure: 400)
      wide = described_class.new(events: 4, exposure: 4)

      expect(narrow.upper - narrow.lower).to be < (wide.upper - wide.lower)
    end
  end

  describe "#per" do
    it "counts the same rate over a longer unit" do
      interval = described_class.new(events: 3, exposure: 22).per(10_000)

      expect(interval.value).to be_within(1e-3).of(1363.636)
      expect(interval.lower).to be_within(1e-1).of(281.2)
      expect(interval.upper).to be_within(1e-1).of(3985.1)
    end

    it "has nothing to scale without exposure" do
      expect(described_class.new(events: 0, exposure: 0).per(10_000).value).to be_nil
    end
  end
end
