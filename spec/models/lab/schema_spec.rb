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

  it "drops the parameters a run never carries from the defaults a sweep starts from" do
    expect(described_class.run_defaults.keys)
      .to eq(%w[width height tape_len radius max_steps mutation_rate init top_k])
  end

  it "keeps the engine's own value for every default a sweep starts from" do
    expect(described_class.run_defaults).to eq(described_class.defaults.except(*Lab::Schema::NON_RUN_PARAMS))
  end

  it "knows a parameter the engine declares" do
    expect(described_class).to be_param("mutation_rate")
  end

  it "does not know a parameter the engine has never heard of" do
    expect(described_class).not_to be_param("mutaiton_rate")
  end
end
