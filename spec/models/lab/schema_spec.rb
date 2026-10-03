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
      .to eq("threshold" => 0.6, "hold_samples" => 3, "max_op_density" => 0.9, "min_alphabet_size" => 16,
             "relative_fraction" => 0.61, "baseline_epochs" => 500)
  end

  it "exposes an enum's values" do
    expect(described_class.values_for("substrate")).to eq(%w[soup life])
    expect(described_class.values_for("structure")).to eq(%w[uniform gradient patchwork])
    expect(described_class.values_for("interaction")).to eq(%w[concat host])
    expect(described_class.values_for("lineage_rule")).to eq(%w[aligned oriented])
    expect(described_class.values_for("energy_payer")).to eq(%w[pair initiator])
    expect(described_class.values_for("tasks")).to eq(%w[off arith logic logic3 logic4])
    expect(described_class.values_for("task_floor"))
      .to eq(%w[echo inc dec add sub not double mul nand and orn or andn nor xor equ])
    expect(described_class.values_for("logic_nand")).to eq(%w[in_place stack])
    expect(described_class.values_for("predation")).to eq(%w[off subset_class equal shadow])
  end

  it "reads the task ladder in the engine's order, the bit order of dominant_tasks" do
    expect(described_class.task_names).to eq(%w[echo inc dec add sub not double mul])
  end

  it "reads the logic ladder in the engine's order, the bit order of dominant_logic_tasks" do
    expect(described_class.logic_task_names).to eq(%w[echo not nand and orn or andn nor xor equ])
  end

  it "has no values for a numeric parameter" do
    expect(described_class.values_for("width")).to eq([])
  end

  it "refuses a parameter the engine does not have" do
    expect { described_class.field("nonsense") }.to raise_error(ArgumentError)
  end

  it "drops the parameters a run never carries from the defaults a sweep starts from" do
    expect(described_class.run_defaults.keys)
      .to eq(%w[width height tape_len max_tape_len radius max_steps energy_per_epoch energy_influx
                energy_stock_cap energy_payer steal_amount steal_loss tasks task_every task_reward task_floor
                logic_nand task_depth_cap task_max_outputs predation predation_transfer predation_loss
                predation_every predation_shadow_p ops
                mutation_rate structure structure_amplitude
                interaction lineage_rule meta_len meta_rate meta_draw meta_seed init top_k])
  end

  # Pinned by value rather than derived from the schema: an engine default moving under
  # `make schema` would otherwise silently change the params of every sweep queued after it.
  it "keeps the engine's own value for every default a sweep starts from" do
    expect(described_class.run_defaults).to eq(
      "width" => 128, "height" => 128, "tape_len" => 64, "max_tape_len" => 0, "radius" => 1, "max_steps" => 2**13,
      "energy_per_epoch" => 0, "energy_influx" => 0, "energy_stock_cap" => 0, "energy_payer" => "pair",
      "steal_amount" => 0, "steal_loss" => 0.5, "tasks" => "off", "task_every" => 8, "task_reward" => 0,
      "task_floor" => "echo", "logic_nand" => "in_place", "task_depth_cap" => 0, "task_max_outputs" => 4,
      "predation" => "off", "predation_transfer" => 0, "predation_loss" => 0.5, "predation_every" => 8,
      "predation_shadow_p" => 0.3, "ops" => "<>{}+-.,[]", "mutation_rate" => 1.0 / 4096,
      "structure" => "uniform", "structure_amplitude" => 0.5, "interaction" => "concat",
      "lineage_rule" => "aligned", "meta_len" => 0, "meta_rate" => 32.0 / 8192, "meta_draw" => "uniform",
      "meta_seed" => "zeros", "init" => "random", "top_k" => 16
    )
  end

  it "knows a parameter the engine declares" do
    expect(described_class).to be_param("mutation_rate")
  end

  it "does not know a parameter the engine has never heard of" do
    expect(described_class).not_to be_param("mutaiton_rate")
  end
end
