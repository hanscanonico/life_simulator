# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab do
  describe ".slug_for" do
    it "spells a sweep key as its experiment slug" do
      expect(described_class.slug_for("bff_control")).to eq("bff-control")
    end

    it "leaves a single-word key alone" do
      expect(described_class.slug_for("radius")).to eq("radius")
    end
  end

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

    describe "the bff_control positive control" do
      let(:definition) { Lab::SWEEPS.fetch("bff_control") }

      it "runs a well-mixed soup of 2^17 tapes" do
        expect(definition[:param_grid])
          .to eq("mutation_rate" => [0.0, 2.0**-12], "width" => [512], "height" => [256], "radius" => [0],
                 "sample_every" => [50], "snapshot_every" => [2_000])
      end

      it "gives three seeds 50 000 epochs each" do
        expect(definition.values_at(:seeds, :epochs)).to eq([[1, 2, 3], 50_000])
      end

      it "jumps the queue ahead of the sweeps" do
        expect(definition[:priority]).to eq(10)
      end

      it "snapshots the big world sparsely, not at the engine's cadence" do
        expect(definition[:param_grid].values_at("sample_every", "snapshot_every").flatten)
          .to eq([50, 2_000])
        expect(Lab::Schema.defaults.values_at("sample_every", "snapshot_every")).to eq([10, 100])
      end
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
