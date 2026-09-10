# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::Schema do
  it "reads every parameter the engine declares" do
    expect(described_class.fields.pluck("name")).to include("substrate", "width", "mutation_rate")
  end

  it "exposes the engine's defaults" do
    expect(described_class.defaults).to include("substrate" => "soup", "width" => 128, "tape_len" => 64)
  end

  it "exposes an enum's values" do
    expect(described_class.values_for("substrate")).to eq(%w[soup life])
  end

  it "has no values for a numeric parameter" do
    expect(described_class.values_for("width")).to eq([])
  end

  it "refuses a parameter the engine does not have" do
    expect { described_class.field("nonsense") }.to raise_error(ArgumentError)
  end
end
