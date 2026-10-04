# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::CanonicalParams do
  describe ".for" do
    it "fills in the engine defaults a stored run never carried" do
      stored = Lab::Schema.run_defaults.except("ops").merge("radius" => 2)

      expect(described_class.for(stored)).to eq(described_class.for(Lab::Schema.run_defaults.merge("radius" => 2)))
    end

    it "reads a run stored before the lineage rule existed as the aligned arm it ran" do
      stored = Lab::Schema.run_defaults.except("lineage_rule")

      expect(described_class.for(stored)).to eq(described_class.for(Lab::Schema.run_defaults))
      expect(described_class.for(stored)).to include("lineage_rule" => "aligned")
    end

    it "keeps an oriented run apart from the aligned one" do
      expect(described_class.for("lineage_rule" => "oriented")).not_to eq(described_class.for({}))
    end

    it "reads a run stored before the energy payer existed as the pair arm it ran" do
      stored = Lab::Schema.run_defaults.except("energy_payer")

      expect(described_class.for(stored)).to eq(described_class.for(Lab::Schema.run_defaults))
      expect(described_class.for(stored)).to include("energy_payer" => "pair")
    end

    it "reads a run stored before tasks existed as the run with tasks off" do
      stored = Lab::Schema.run_defaults.except("tasks", "task_every", "task_reward")

      expect(described_class.for(stored)).to eq(described_class.for(Lab::Schema.run_defaults))
      expect(described_class.for(stored)).to include("tasks" => "off", "task_every" => 8, "task_reward" => 0)
    end

    it "reads a run stored before the task floor existed as the run that paid every rung" do
      stored = Lab::Schema.run_defaults.except("task_floor").merge("tasks" => "arith", "task_reward" => 2048)

      expect(described_class.for(stored))
        .to eq(described_class.for(stored.merge("task_floor" => "echo")))
      expect(described_class.for(stored)).to include("task_floor" => "echo")
    end

    it "reads a run stored before the logic NAND existed as the in-place run it was" do
      stored = Lab::Schema.run_defaults.except("logic_nand").merge("tasks" => "logic", "task_reward" => 2048)

      expect(described_class.for(stored))
        .to eq(described_class.for(stored.merge("logic_nand" => "in_place")))
      expect(described_class.for(stored)).to include("logic_nand" => "in_place")
    end

    it "reads a run stored before the depth cap existed as the uncapped run it was" do
      stored = Lab::Schema.run_defaults.except("task_depth_cap").merge("tasks" => "logic", "task_reward" => 2048)

      expect(described_class.for(stored)).to eq(described_class.for(stored.merge("task_depth_cap" => 0)))
      expect(described_class.for(stored)).to include("task_depth_cap" => 0)
    end

    it "keeps a capped topless arm apart from its uncapped twin, and each ladder apart" do
      rise = { "tasks" => "logic4", "task_reward" => 1024 }

      expect(described_class.for(rise)).not_to eq(described_class.for(rise.merge("task_depth_cap" => 5)))
      expect(described_class.for(rise)).not_to eq(described_class.for(rise.merge("tasks" => "logic3")))
    end

    it "reads a run stored before predation existed as the run without it, at four slots" do
      grown = %w[task_max_outputs predation predation_transfer predation_loss predation_every predation_shadow_p]
      stored = Lab::Schema.run_defaults.except(*grown).merge("tasks" => "logic4", "task_reward" => 512)

      expect(described_class.for(stored))
        .to eq(described_class.for(stored.merge("task_max_outputs" => 4, "predation" => "off",
                                                "predation_transfer" => 0, "predation_loss" => 0.5,
                                                "predation_every" => 8, "predation_shadow_p" => 0.3)))
    end

    it "keeps each predation arm apart from the others and from the arm without it" do
      none = { "tasks" => "logic4", "meta_len" => 32, "task_max_outputs" => 16, "predation_transfer" => 8192 }
      arms = %w[off subset_class equal shadow].map { |rule| described_class.for(none.merge("predation" => rule)) }

      expect(arms.uniq.size).to eq(4)
      expect(described_class.for(none)).to eq(arms.first)
      expect(described_class.for(none)).not_to eq(described_class.for(none.merge("task_max_outputs" => 4)))
    end

    it "reads a run stored before the growable channel and genes existed as the run without them" do
      grown = %w[meta_max_len meta_min_len meta_dup meta_del meta_seg_max meta_genes]
      stored = Lab::Schema.run_defaults.except(*grown).merge("tasks" => "logic4", "meta_len" => 32)

      expect(described_class.for(stored))
        .to eq(described_class.for(stored.merge("meta_max_len" => 0, "meta_min_len" => 8, "meta_dup" => 0.0,
                                                "meta_del" => 0.0, "meta_seg_max" => 16, "meta_genes" => 0)))
    end

    it "keeps the count, capped, genes and drift arms apart" do
      count = { "tasks" => "logic4", "meta_len" => 32, "task_max_outputs" => 16, "predation" => "count",
                "predation_transfer" => 8192, "meta_max_len" => 8192, "meta_dup" => 0.05, "meta_del" => 0.05,
                "meta_genes" => 32 }
      arms = [count, count.merge("meta_max_len" => 1024), count.merge("predation" => "off"),
              count.merge("meta_genes" => 0), count.merge("predation" => "subset_class")]

      expect(arms.map { |arm| described_class.for(arm) }.uniq.size).to eq(5)
    end

    it "reads a run stored before fidelity existed as the run without it" do
      fidelity = %w[meta_fid_max meta_fid_rate meta_fid_alpha]
      stored = Lab::Schema.run_defaults.except(*fidelity).merge("tasks" => "logic4", "meta_len" => 32,
                                                                "meta_max_len" => 8192, "meta_dup" => 0.05)

      expect(described_class.for(stored))
        .to eq(described_class.for(stored.merge("meta_fid_max" => 0, "meta_fid_rate" => 0.0,
                                                "meta_fid_alpha" => 0.0)))
    end

    it "keeps the costly, free, unstaged and fixed fidelity arms apart" do
      costly = { "tasks" => "logic4", "meta_len" => 32, "task_max_outputs" => 16, "predation" => "count",
                 "predation_transfer" => 8192, "meta_max_len" => 8192, "meta_dup" => 0.05, "meta_del" => 0.05,
                 "meta_genes" => 32, "meta_fid_max" => 16, "meta_fid_rate" => 0.05, "meta_fid_alpha" => 0.03 }
      arms = [costly, costly.merge("meta_fid_alpha" => 0.0), costly.merge("meta_fid_alpha" => 0.01),
              costly.merge("meta_fid_max" => 8), costly.except("meta_fid_max", "meta_fid_rate", "meta_fid_alpha")]

      expect(arms.map { |arm| described_class.for(arm) }.uniq.size).to eq(5)
    end

    it "keeps a stack-NAND arm apart from its in-place twin" do
      full = { "tasks" => "logic", "task_reward" => 2048 }

      expect(described_class.for(full)).not_to eq(described_class.for(full.merge("logic_nand" => "stack")))
    end

    it "keeps a deep-only arm apart from its full-ladder twin" do
      full = { "tasks" => "logic", "task_reward" => 2048 }

      expect(described_class.for(full)).not_to eq(described_class.for(full.merge("task_floor" => "xor")))
    end

    it "keeps a rewarded arm apart from its unrewarded twin" do
      rewarded = { "tasks" => "arith", "task_reward" => 2048 }

      expect(described_class.for(rewarded)).not_to eq(described_class.for(rewarded.merge("task_reward" => 0)))
    end

    it "reads a run stored before the metabolism tape existed as the run without one" do
      meta_keys = %w[meta_len meta_rate meta_draw meta_seed]
      stored = Lab::Schema.run_defaults.except(*meta_keys).merge("tasks" => "logic", "task_reward" => 2048)

      expect(described_class.for(stored)).to eq(described_class.for(stored.merge(Lab::Schema.run_defaults.slice(*meta_keys))))
      expect(described_class.for(stored))
        .to include("meta_len" => 0, "meta_rate" => Rational(1, 256), "meta_draw" => "uniform", "meta_seed" => "zeros")
    end

    it "keeps a metabolism-tape arm apart from its woven twin" do
      woven = { "tasks" => "logic", "task_reward" => 2048 }
      meta = woven.merge("meta_len" => 32, "meta_rate" => 0.00390625, "meta_draw" => "isa", "meta_seed" => "own_tape")

      expect(described_class.for(meta)).not_to eq(described_class.for(woven))
      expect(described_class.for(meta)).not_to eq(described_class.for(meta.merge("meta_seed" => "zeros")))
    end

    it "keeps an initiator run apart from the pair one" do
      expect(described_class.for("energy_payer" => "initiator")).not_to eq(described_class.for({}))
    end

    it "reads an integer and a float of the same value as one arm" do
      expect(described_class.for("radius" => 0)).to eq(described_class.for("radius" => 0.0))
    end

    it "ignores the order the keys were written in" do
      expect(described_class.for("radius" => 2, "width" => 32))
        .to eq(described_class.for("width" => 32, "radius" => 2))
    end

    it "keeps arms that differ apart" do
      expect(described_class.for("radius" => 2)).not_to eq(described_class.for("radius" => 4))
    end
  end

  describe ".same_value?" do
    it "matches a stored integer against its rake argument" do
      expect(described_class).to be_same_value(64, "64")
    end

    it "matches a stored float against a differently written argument" do
      expect(described_class).to be_same_value(0.0, "0")
    end

    it "matches a stored string exactly" do
      expect(described_class).to be_same_value("<>{}+-.,[]", "<>{}+-.,[]")
    end

    it "does not match a different number" do
      expect(described_class).not_to be_same_value(64, "0")
    end

    it "does not match a number against a word" do
      expect(described_class).not_to be_same_value(64, "sixty-four")
    end
  end

  describe ".structure_of" do
    it "reads the structural keys alone, with the engine defaults filled in" do
      structure = described_class.structure_of({ "mutation_rate" => 0.01, "width" => 32 }, substrate: "soup")

      expect(structure).to eq("substrate" => "soup", "width" => 32, "height" => 128, "tape_len" => 64,
                              "max_tape_len" => 0, "ops" => Lab::FULL_INSTRUCTION_SET)
    end

    it "reads the lineage rule as dynamics a descendant may change" do
      expect(described_class.structure_of({ "lineage_rule" => "oriented" }, substrate: "soup"))
        .to eq(described_class.structure_of({}, substrate: "soup"))
    end

    it "reads the task assay as dynamics a descendant may change" do
      expect(described_class.structure_of({ "tasks" => "arith", "task_every" => 4, "task_reward" => 512 },
                                          substrate: "soup"))
        .to eq(described_class.structure_of({}, substrate: "soup"))
    end

    it "reads the logic ladder and its floor as dynamics a descendant may change" do
      expect(described_class.structure_of({ "tasks" => "logic", "task_reward" => 512, "task_floor" => "xor" },
                                          substrate: "soup"))
        .to eq(described_class.structure_of({}, substrate: "soup"))
    end

    it "reads the logic NAND as dynamics a descendant may change" do
      expect(described_class.structure_of({ "tasks" => "logic", "logic_nand" => "stack" }, substrate: "soup"))
        .to eq(described_class.structure_of({}, substrate: "soup"))
    end

    it "reads the energy payer as dynamics a descendant may change" do
      expect(described_class.structure_of({ "energy_payer" => "initiator" }, substrate: "soup"))
        .to eq(described_class.structure_of({}, substrate: "soup"))
    end

    it "reads two runs that differ in dynamics alone as one structure" do
      expect(described_class.structure_of({ "mutation_rate" => 0.01, "radius" => 2 }, substrate: "soup"))
        .to eq(described_class.structure_of({ "energy_influx" => 4 }, substrate: "soup"))
    end

    it "prefers a substrate the run carries over the experiment's" do
      expect(described_class.structure_of({ "substrate" => "life" }, substrate: "soup")["substrate"]).to eq("life")
    end
  end
end
