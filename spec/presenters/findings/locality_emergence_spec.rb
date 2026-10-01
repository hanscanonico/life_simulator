# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::LocalityEmergence do
  subject(:reading) { described_class.build(report_of(sweep), exploratory: exploratory) }

  let(:sweep) { locality_emergence_experiment }
  let(:exploratory) { nil }

  def report_of(experiment) = Experiments::LocalityEmergenceReadingService.call(experiment: experiment)

  def arm_of(radius, emerged:, finished:, crossed: emerged, experiment: sweep, first_seed: 91)
    Array.new(finished) do |index|
      share = if index < emerged then 0.9
              elsif index < crossed then 0.2
              end
      locality_run(experiment, radius: radius, share: share, seed: first_seed + index)
    end
  end

  context "with both hypotheses shown" do
    before do
      arm_of(1, emerged: 1, finished: 10, crossed: 2)
      arm_of(4, emerged: 8, finished: 10)
      arm_of(8, emerged: 1, finished: 10)
      arm_of(0, emerged: 0, finished: 10)
    end

    it "states the peak from the report" do
      expect(reading).to be_shown
      expect(reading.claim_sentence)
        .to start_with("Emergence peaks at an intermediate reach: radius 4 emerged in 8 of 10 fresh worlds, " \
                       "against 1 of 10 at radius 1 and 0 of 10 well-mixed")
    end

    it "counts confirmed crossings beside emergence" do
      expect(reading.arms.first).to have_attributes(label: "radius 1", finished: 10, crossed: 2, emerged: 1)
    end
  end

  context "with no peak" do
    before do
      arm_of(1, emerged: 2, finished: 4)
      arm_of(4, emerged: 1, finished: 4)
      arm_of(0, emerged: 2, finished: 4)
    end

    it "names the outcomes instead of a claim" do
      expect(reading.claim_sentence).to start_with("The pre-registered reading shows no peak: H-peak refuted")
    end
  end

  context "beside the exploratory sweep" do
    let(:old_sweep) { lineage_diversity_experiment }
    let(:exploratory) { report_of(old_sweep) }

    before do
      arm_of(1, emerged: 1, finished: 3, crossed: 2)
      arm_of(4, emerged: 2, finished: 3)
      arm_of(1, emerged: 1, finished: 3, crossed: 1, experiment: old_sweep, first_seed: 1)
      arm_of(4, emerged: 1, finished: 3, experiment: old_sweep, first_seed: 1)
    end

    it "names the arms whose totals agree, with both sweeps' crossings and seeds" do
      same = reading.same_total_arms

      expect(same.map(&:label)).to eq(["radius 1"])
      expect(same.first.exploratory.crossed).to eq(1)
      expect(same.first.crossed).to eq(2)
      expect([reading.seed_range, reading.exploratory_seed_range]).to eq([91..93, 1..3])
    end
  end
end
