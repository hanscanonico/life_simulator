# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab do
  describe "SWEEPS" do
    Lab::SWEEPS.each do |slug, definition|
      context "with the #{slug} sweep" do
        it "varies only parameters the engine schema declares" do
          expect(swept_params(definition[:param_grid])).to all(satisfy { |name| Lab::Schema.param?(name) })
        end
      end
    end

    it "sweeps the radius grid of DESIGN 1.3, with 0 as the well-mixed arm" do
      expect(Lab::SWEEPS.fetch("radius")[:param_grid]["radius"]).to eq([1, 2, 4, 0])
    end

    it "cuts the ablations from the instruction set the engine declares" do
      expect(Lab::FULL_INSTRUCTION_SET).to eq(Lab::Schema.defaults.fetch("ops"))
    end

    it "ablates one family of ops per arm of the instruction-set sweep" do
      arms = Lab::SWEEPS.fetch("ops")[:param_grid]["ops"]

      expect(arms.first).to eq(Lab::FULL_INSTRUCTION_SET)
      expect(arms.drop(1).map { |arm| Lab::FULL_INSTRUCTION_SET.chars - arm.chars })
        .to eq([[","], ["."], ["[", "]"], ["{", "}"], ["+", "-"]])
    end

    it "runs every ablation at the mutation rate that first produced emergence" do
      expect(Lab::SWEEPS.fetch("ops")[:param_grid]["mutation_rate"]).to eq([2.0**-13])
    end

    # An axis whose values are hashes is a bundle of parameters travelling together, so it
    # is the hash keys that name parameters, not the axis itself.
    def swept_params(param_grid)
      param_grid.flat_map do |name, values|
        bundles = values.grep(Hash)
        bundles.any? ? bundles.flat_map(&:keys) : [name]
      end.uniq
    end
  end
end
