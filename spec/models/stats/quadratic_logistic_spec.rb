# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stats::QuadraticLogistic do
  let(:peaked) { [[1, 4, 90], [2, 9, 90], [3, 14, 90], [4, 16, 90], [6, 12, 90], [8, 6, 90]] }

  it "fits where the likelihood's gradient vanishes" do
    fit = described_class.fit(peaked)
    gradient = [0, 1, 2].map do |power|
      peaked.sum do |x, successes, trials|
        chance = 1 / (1 + Math.exp(-(fit.intercept + (fit.linear * x) + (fit.quadratic * x * x))))
        (successes - (trials * chance)) * (x**power)
      end
    end

    expect(gradient).to all(be_within(1e-6).of(0))
  end

  it "reads a peaked set as a downward parabola with its peak inside the radii" do
    fit = described_class.fit(peaked)

    expect(fit.quadratic).to be_negative
    expect(fit.wald_p).to be < 0.01
    expect(fit.peak).to be_within(0.01).of(4.59)
  end

  it "reads a flat set as its common rate, with no curvature" do
    fit = described_class.fit([1, 2, 3, 4, 6, 8].map { |x| [x, 10, 90] })

    expect(fit.intercept).to be_within(1e-9).of(Math.log(1.0 / 8))
    expect([fit.linear, fit.quadratic]).to all(be_within(1e-9).of(0))
    expect(fit.wald_p).to be > 0.99
  end

  context "with a set the curve separates" do
    it "gives no fit" do
      expect(described_class.fit([[1, 0, 90], [2, 90, 90], [3, 0, 90]])).to be_nil
    end
  end

  context "with nothing succeeding" do
    it "gives no fit" do
      expect(described_class.fit([[1, 0, 90], [2, 0, 90], [3, 0, 90]])).to be_nil
    end
  end
end
