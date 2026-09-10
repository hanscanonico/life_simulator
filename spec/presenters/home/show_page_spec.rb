# frozen_string_literal: true

require "rails_helper"

RSpec.describe Home::ShowPage do
  subject(:page) { described_class.build(seed: 7) }

  it "offers the substrates the engine declares" do
    expect(page.substrates).to eq(Lab::Schema.values_for("substrate"))
    expect(page.substrate).to eq("soup")
  end

  it "keeps the given seed" do
    expect(page.seed).to eq(7)
  end

  it "draws a seed of its own without one" do
    expect(described_class.build.seed).to be_between(0, described_class::MAX_SEED)
  end

  it "builds every substrate's params from the engine defaults, at viewer size" do
    expect(page.worlds.keys).to eq(page.substrates)

    soup = page.worlds.fetch("soup")
    expect(soup["width"]).to eq(described_class::VIEWER_SIZE)
    expect(soup["height"]).to eq(described_class::VIEWER_SIZE)
    expect(soup["tape_len"]).to eq(Lab::Schema.defaults.fetch("tape_len"))
    expect(soup["mutation_rate"]).to eq(Lab::Schema.defaults.fetch("mutation_rate"))
  end

  it "runs the life substrate without mutation" do
    expect(page.worlds.fetch("life")["mutation_rate"]).to eq(0.0)
  end

  it "points at the wasm build" do
    expect(page.wasm_url).to match(%r{/assets/life_engine_bg.*\.wasm})
  end

  context "with no wasm build on disk" do
    it "has no wasm url" do
      allow(ActionController::Base.helpers).to receive(:asset_path).and_raise(Propshaft::MissingAssetError.new("x"))

      expect(page.wasm_url).to be_nil
    end
  end
end
