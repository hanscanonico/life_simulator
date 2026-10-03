# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::ReachCap128 do
  subject(:reading) { described_class.build(Experiments::ReachCap128ReadingService.call(experiment: sweep)) }

  let(:sweep) { reach_cap128_experiment }
  let(:control) { host_parasite_control_experiment }

  def arm(emerged:, counted:, &run)
    Array.new(counted) do |index|
      run.call(index < emerged ? { crossing: 1_000, shares: [0.0, 0.9, 0.9] } : {})
    end
  end

  context "with H-reach128 shown" do
    before do
      arm(emerged: 8, counted: 10) { |options| reach_run(sweep, **options) }
      arm(emerged: 1, counted: 10) { |options| control_run(control, **options) }
    end

    it "states the claim and the ratio of the rates from the report" do
      expect(reading).to be_shown
      expect(reading.claim_sentence)
        .to eq("With room to grow, radius 4 emerged in 8 of 10 worlds, against 1 of 10 in the radius-1 " \
               "control: 8.0 times the rate.")
    end

    it "carries the report's exact p" do
      expect(reading.p_value).to eq(Stats::FisherExact.greater([[8, 2], [1, 9]]))
    end
  end

  context "with the control emerging nowhere" do
    before do
      arm(emerged: 8, counted: 10) { |options| reach_run(sweep, **options) }
      arm(emerged: 0, counted: 10) { |options| control_run(control, **options) }
    end

    it "states the claim without a ratio" do
      expect(reading.rate_ratio).to be_nil
      expect(reading.claim_sentence).to end_with("against 0 of 10 in the radius-1 control.")
    end
  end

  context "with the effect absent" do
    before do
      arm(emerged: 1, counted: 4) { |options| reach_run(sweep, **options) }
      arm(emerged: 2, counted: 4) { |options| control_run(control, **options) }
    end

    it "names the outcome instead of a claim" do
      expect(reading).not_to be_shown
      expect(reading.claim_sentence).to end_with("H-reach128 refuted.")
    end
  end

  context "with no run in the sweep" do
    it "has nothing to read" do
      expect(reading.any?).to be(false)
    end
  end
end
