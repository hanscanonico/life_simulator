# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::Schema do
  it "reads every parameter the engine declares" do
    expect(described_class.fields.pluck("name")).to include("substrate", "width", "mutation_rate")
  end

  it "exposes the engine's defaults" do
    expect(described_class.defaults).to include("substrate" => "soup", "width" => 128, "tape_len" => 64)
  end

  it "reads the transition rule the engine measures by" do
    expect(described_class.transition)
      .to eq("threshold" => 0.6, "hold_samples" => 3, "max_op_density" => 0.9, "min_alphabet_size" => 16)
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
      .to eq(%w[width height tape_len radius max_steps ops mutation_rate init top_k])
  end

  # Pinned by value rather than derived from the schema: an engine default moving under
  # `make schema` would otherwise silently change the params of every sweep queued after it.
  it "keeps the engine's own value for every default a sweep starts from" do
    expect(described_class.run_defaults).to eq(
      "width" => 128, "height" => 128, "tape_len" => 64, "radius" => 1, "max_steps" => 2**13,
      "ops" => "<>{}+-.,[]", "mutation_rate" => 1.0 / 4096, "init" => "random", "top_k" => 16
    )
  end

  it "knows a parameter the engine declares" do
    expect(described_class).to be_param("mutation_rate")
  end

  it "does not know a parameter the engine has never heard of" do
    expect(described_class).not_to be_param("mutaiton_rate")
  end
end
