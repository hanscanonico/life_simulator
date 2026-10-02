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

    describe "the mutation_rate_long re-run" do
      let(:definition) { Lab::SWEEPS.fetch("mutation_rate_long") }

      it "re-runs the four rates around sweep 1's transitions, at three times its budget" do
        expect(definition[:param_grid].fetch("mutation_rate")).to eq([2.0**-14, 2.0**-13, 2.0**-12, 2.0**-11])
        expect(definition.fetch(:epochs)).to eq(3 * Lab::SWEEPS.fetch("mutation_rate").fetch(:epochs))
      end

      it "keeps the world of the sweep it re-runs so a run repeats it byte for byte" do
        expect(definition[:param_grid].values_at("width", "height")).to eq([[128], [128]])
        expect(definition.fetch(:seeds)).to eq(Lab::SWEEPS.fetch("mutation_rate").fetch(:seeds))
      end

      it "snapshots the long runs sparsely, not at the engine's cadence" do
        expect(definition[:param_grid].fetch("snapshot_every")).to eq([500])
        expect(Lab::Schema.defaults.fetch("snapshot_every")).to eq(100)
      end
    end

    describe "the instruction-cost sweep" do
      let(:definition) { Lab::SWEEPS.fetch("energy_per_epoch") }

      it "prices an interaction against the step budget it is cut from" do
        full_interaction = Lab::Schema.defaults.fetch("max_steps")

        expect(definition[:param_grid].fetch("energy_per_epoch"))
          .to eq([0, 4 * full_interaction, full_interaction, full_interaction / 4])
      end

      it "carries the arm where the cost is off, the substrate every other sweep ran" do
        expect(definition[:param_grid].fetch("energy_per_epoch").first)
          .to eq(Lab::Schema.defaults.fetch("energy_per_epoch"))
      end

      it "runs every arm at the mutation rate that first produced emergence" do
        expect(definition[:param_grid].fetch("mutation_rate")).to eq([Lab::EMERGENT_MUTATION_RATE])
      end

      it "gives thirty seeds the sweep epoch budget each, enough for two emergences per arm" do
        expect(definition.values_at(:seeds, :epochs)).to eq([(1..30).to_a, 20_000])
      end
    end

    describe "the environmental-structure sweep" do
      let(:definition) { Lab::SWEEPS.fetch("environmental_structure") }

      it "sweeps the uniform world against the two structured ones" do
        expect(definition[:param_grid].fetch("structure")).to eq(%w[uniform gradient patchwork])
      end

      it "carries the uniform arm the engine defaults to, the world every other sweep ran" do
        expect(definition[:param_grid].fetch("structure").first)
          .to eq(Lab::Schema.defaults.fetch("structure"))
      end

      it "keeps the dry and the wet cells of a structured world inside the rate window sweep 1 mapped" do
        amplitude = definition[:param_grid].fetch("structure_amplitude").sole
        rates = [1 - amplitude, 1 + amplitude].map { |scale| Lab::EMERGENT_MUTATION_RATE * scale }

        expect(rates.min).to be >= 2.0**-16
        expect(rates.max).to be <= 2.0**-8
      end

      it "runs every arm at the mutation rate that first produced emergence" do
        expect(definition[:param_grid].fetch("mutation_rate")).to eq([Lab::EMERGENT_MUTATION_RATE])
      end

      it "gives thirty seeds the sweep epoch budget each, enough for two emergences per arm" do
        expect(definition.values_at(:seeds, :epochs)).to eq([(1..30).to_a, 20_000])
      end

      it "gives the two structured arms ninety seeds and the uniform control thirty" do
        expect(definition.fetch(:seeds_by_arm))
          .to eq("structure" => { "gradient" => (1..90).to_a, "patchwork" => (1..90).to_a })
      end
    end

    describe "the room-to-grow sweep" do
      let(:definition) { Lab::SWEEPS.fetch("max_tape_len") }

      it "doubles the cap from the length a tape starts at" do
        expect(definition[:param_grid].fetch("max_tape_len")).to eq([64, 128, 256, 512])
      end

      it "carries the arm where growth is off, the fixed-tape world every other sweep ran" do
        tape_len = definition[:param_grid].fetch("tape_len").sole

        expect(tape_len).to eq(Lab::Schema.defaults.fetch("tape_len"))
        expect(definition[:param_grid].fetch("max_tape_len").first).to eq(tape_len)
      end

      it "runs every arm at the mutation rate that first produced emergence" do
        expect(definition[:param_grid].fetch("mutation_rate")).to eq([Lab::EMERGENT_MUTATION_RATE])
      end

      it "gives thirty seeds the sweep epoch budget each, enough for two emergences per arm" do
        expect(definition.values_at(:seeds, :epochs)).to eq([(1..30).to_a, 20_000])
      end

      it "gives the two arms with one measured emergence ninety seeds, the control and the empty arm thirty" do
        expect(definition.fetch(:seeds_by_arm))
          .to eq("max_tape_len" => { 128 => (1..90).to_a, 256 => (1..90).to_a })
      end
    end

    describe "the host-parasite sweep" do
      let(:definition) { Lab::SWEEPS.fetch("host_parasite") }
      let(:economy) { definition[:param_grid].fetch("economy") }

      it "crosses three influx levels with theft on and off, under one control at the defaults" do
        expect(economy).to eq(
          [{ "energy_influx" => 0, "steal_amount" => 0 },
           { "energy_influx" => 2**13, "steal_amount" => 0 },
           { "energy_influx" => 2**13, "steal_amount" => 2**10 },
           { "energy_influx" => 2**11, "steal_amount" => 0 },
           { "energy_influx" => 2**11, "steal_amount" => 2**10 },
           { "energy_influx" => 2**9, "steal_amount" => 0 },
           { "energy_influx" => 2**9, "steal_amount" => 2**10 }]
        )
      end

      it "carries the arm where the economy is off, the substrate every other sweep ran" do
        expect(economy.first)
          .to eq(Lab::Schema.defaults.slice("energy_influx", "steal_amount"))
      end

      it "prices the influx against the step budget one interaction is cut from" do
        full_interaction = Lab::Schema.defaults.fetch("max_steps")

        expect(economy.filter_map { |arm| arm["energy_influx"].positive? ? arm["energy_influx"] : nil }.uniq)
          .to eq([full_interaction, full_interaction / 4, full_interaction / 16])
      end

      it "keeps every priced arm's hoard under one ceiling, four full interactions high" do
        cap = definition[:param_grid].fetch("energy_stock_cap").sole

        expect(cap).to eq(4 * Lab::Schema.defaults.fetch("max_steps"))
        expect(economy.map { |arm| arm.fetch("energy_influx") }).to all(be <= cap)
      end

      it "pays a thief something for every steal it runs" do
        loss = definition[:param_grid].fetch("steal_loss").sole
        amount = economy.filter_map { |arm| arm["steal_amount"] }.max

        expect(loss).to eq(Lab::Schema.defaults.fetch("steal_loss"))
        expect((amount * (1 - loss)).floor).to be_positive
      end

      it "runs both room-to-grow caps at the mutation rate that first produced emergence" do
        expect(definition[:param_grid].values_at("max_tape_len", "tape_len", "mutation_rate"))
          .to eq([[128, 256], [64], [Lab::EMERGENT_MUTATION_RATE]])
      end

      it "gives every arm ninety seeds, the control included" do
        expect(definition.values_at(:seeds, :epochs)).to eq([(1..90).to_a, 20_000])
      end

      it "gives the one rising arm and the controls at both caps two hundred and seventy seeds" do
        expect(definition.fetch(:seeds_by_arm).to_h { |arm| arm.values_at("params", "seeds") })
          .to eq({ "energy_influx" => 2**11, "steal_amount" => 2**10, "max_tape_len" => 128 } => (1..270).to_a,
                 { "energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 128 } => (1..270).to_a,
                 { "energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 256 } => (1..270).to_a)
      end
    end

    describe "the asymmetric-execution sweep" do
      let(:definition) { Lab::SWEEPS.fetch("asymmetric_execution") }

      it "reads the whole concatenation in its control arm, the substrate every other sweep ran" do
        expect(definition[:param_grid].fetch("interaction")).to eq(%w[concat host])
        expect(definition[:param_grid].fetch("interaction").first)
          .to eq(Lab::Schema.defaults.fetch("interaction"))
      end

      it "crosses the two interaction modes with the two caps whose plateau sweep 8 measured" do
        expect(definition[:param_grid].values_at("max_tape_len", "tape_len", "mutation_rate"))
          .to eq([[128, 256], [64], [Lab::EMERGENT_MUTATION_RATE]])
      end

      it "runs the same 128-square world for the same budget as the sweep it extends" do
        expect(definition[:param_grid].values_at("width", "height")).to eq([[128], [128]])
        expect(definition[:epochs]).to eq(20_000)
      end

      it "gives every arm ninety seeds, the control included" do
        expect(definition[:seeds]).to eq((1..90).to_a)
        expect(definition).not_to have_key(:seeds_by_arm)
      end
    end

    describe "the from-emerged descendant sweep" do
      let(:definition) { Lab::SWEEPS.fetch("from_emerged") }
      let(:host_parasite) { Lab::SWEEPS.fetch("host_parasite") }
      let(:treatments) { definition[:param_grid].fetch("treatment") }

      it "draws its parents from sweep 9's two economy-off controls" do
        controls = host_parasite.fetch(:seeds_by_arm).map { |arm| arm.fetch("params") }
                                .select { |arm| arm.fetch("energy_influx").zero? }

        expect(definition[:parents]).to include("experiment" => "host-parasite", "arms" => controls)
      end

      it "qualifies a parent on the oriented census of its terminal world, at half replicators" do
        expect(definition[:parents].values_at("instrument", "share_key", "min_share"))
          .to eq(["oriented_census/1", "replicator_share", 0.5])
      end

      it "pairs the continuation with sweep 9's rising arm, the rich economy and host mode" do
        expect(treatments).to eq(
          [{},
           { "energy_influx" => 2**11, "steal_amount" => 2**10, "energy_stock_cap" => 2**15, "steal_loss" => 0.5 },
           { "energy_influx" => 2**13, "steal_amount" => 2**10, "energy_stock_cap" => 2**15, "steal_loss" => 0.5 },
           { "interaction" => "host" }]
        )
      end

      it "changes no parameter that shapes the parent's world" do
        expect(treatments.flat_map(&:keys) & Lab::CanonicalParams::STRUCTURAL_KEYS).to be_empty
      end

      it "runs the same three seeds under every treatment, none a parent's own" do
        parent_seeds = host_parasite.fetch(:seeds_by_arm).flat_map { |arm| arm.fetch("seeds") }

        expect(definition[:seeds]).to eq([1001, 1002, 1003])
        expect(definition[:seeds] & parent_seeds).to be_empty
      end

      it "gives every child twenty thousand epochs past its parent" do
        expect(definition[:epochs]).to eq(20_000)
      end

      it "runs ahead of sweep 9's seed-major extension" do
        expect(definition[:priority]).to be > 0
      end
    end

    describe "the locality-emergence sweep" do
      let(:definition) { Lab::SWEEPS.fetch("locality_emergence") }

      it "runs sweep 12's world at seven reaches, well-mixed included" do
        expect(definition[:param_grid].except("radius"))
          .to eq(Lab::SWEEPS.fetch("lineage_diversity")[:param_grid].except("radius"))
        expect(definition[:param_grid].fetch("radius")).to eq(Lab::LocalityEmergenceReading::RADIUS_ORDER)
      end

      it "reaches no further than the engine's radius range, nor than the torus allows" do
        widest = definition[:param_grid].fetch("radius").max
        expect(widest).to be <= Lab::Schema.field("radius")["max"]
        expect((2 * widest) + 1).to be <= definition[:param_grid].fetch("width").first
      end

      it "seeds fresh worlds, none of them sweep 12's" do
        expect(definition[:seeds]).to eq((91..180).to_a)
        expect(definition[:seeds] & Lab::SWEEPS.fetch("lineage_diversity")[:seeds]).to be_empty
      end

      it "gives 630 runs of twenty thousand epochs" do
        expect(definition[:param_grid].fetch("radius").size * definition[:seeds].size).to eq(630)
        expect(definition[:epochs]).to eq(20_000)
      end

      it "runs after the from-emerged children and ahead of the lineage-diversity sweep's priority" do
        expect(definition[:priority]).to be_between(Lab::SWEEPS.fetch("lineage_diversity")[:priority] + 1,
                                                    Lab::SWEEPS.fetch("from_emerged")[:priority] - 1)
      end
    end

    describe "the reach-cap128 sweep" do
      let(:definition) { Lab::SWEEPS.fetch("reach_cap128") }
      let(:params) { Lab::CanonicalParams.for(definition[:param_grid].transform_values(&:first)) }
      let(:control) do
        grid = Lab::SWEEPS.fetch("host_parasite")[:param_grid]
        Lab::CanonicalParams.for(grid.except("economy").transform_values(&:first)
                                     .merge(grid.fetch("economy").first, Lab::ReachCap128Reading::CONTROL_ARM))
      end

      it "runs sweep 9's economy-off cap-128 control at radius 4, every other parameter that arm's" do
        expect(definition[:param_grid].values.map(&:size).uniq).to eq([1])
        expect(params.except("radius", "lineage_rule")).to eq(control.except("radius", "lineage_rule"))
        expect([params["radius"], control["radius"]]).to eq([Lab::ReachCap128Reading::TREATMENT_RADIUS, 1])
      end

      it "names an economy-off control arm sweep 9 runs at 270 seeds" do
        expect(control.values_at("energy_influx", "steal_amount", "max_tape_len")).to eq([0, 0, 128])
        expect(Lab::SWEEPS.fetch("host_parasite")[:seeds_by_arm])
          .to include({ "params" => Lab::ReachCap128Reading::CONTROL_ARM, "seeds" => (1..270).to_a })
      end

      it "inherits lineage tags through reverse copies" do
        expect(definition[:param_grid].fetch("lineage_rule")).to eq(["oriented"])
      end

      it "gives 270 runs of twenty thousand epochs, the control's seeds" do
        expect(definition[:seeds]).to eq((1..270).to_a)
        expect(definition[:epochs]).to eq(20_000)
        expect(definition[:priority]).to eq(30)
      end
    end

    describe "the metabolism sweep" do
      let(:definition) { Lab::SWEEPS.fetch("metabolism") }
      let(:treatments) { definition[:param_grid].fetch("treatment") }

      it "starts from the from-emerged sweep's parents under the same rule" do
        expect(definition[:parents]).to equal(Lab::SWEEPS.fetch("from_emerged")[:parents])
      end

      it "pairs a rewarded arm with its unpaid twin under the same economy and assay" do
        expect(treatments).to eq(
          [{ "energy_payer" => "initiator", "energy_influx" => 1024, "energy_stock_cap" => 65_536, "steal_amount" => 0,
             "tasks" => "arith", "task_every" => 8, "task_reward" => 2048 },
           { "energy_payer" => "initiator", "energy_influx" => 1024, "energy_stock_cap" => 65_536, "steal_amount" => 0,
             "tasks" => "arith", "task_every" => 8, "task_reward" => 0 }]
        )
      end

      it "sets only parameters the engine declares, each to a value it accepts" do
        treatments.flat_map(&:to_a).each do |name, value|
          field = Lab::Schema.field(name)
          if field["values"]
            expect(field["values"]).to include(value)
          else
            expect(value).to be_between(field["min"], field["max"])
          end
        end
      end

      it "prices an interaction at the step budget and keeps eight prices of stock" do
        max_steps = Lab::Schema.defaults.fetch("max_steps")

        expect(treatments.map { |bundle| bundle.fetch("energy_stock_cap") }).to all(eq(8 * max_steps))
        expect(treatments.map { |bundle| bundle.fetch("energy_influx") }).to all(eq(max_steps / 8))
      end

      it "labels the rewarded arm alone a Metabolism run" do
        expect(treatments.map { |bundle| Lab::MetabolismReading.metabolism_run?(bundle) }).to eq([true, false])
      end

      it "changes no parameter that shapes the parent's world" do
        expect(treatments.flat_map(&:keys) & Lab::CanonicalParams::STRUCTURAL_KEYS).to be_empty
      end

      it "runs three seeds no parent and no from-emerged child carries" do
        expect(definition[:seeds]).to eq([2001, 2002, 2003])
        expect(definition[:seeds] & Lab::SWEEPS.fetch("from_emerged")[:seeds]).to be_empty
        expect(definition[:seeds].min).to be > Lab::SWEEPS.fetch("host_parasite")[:seeds_by_arm]
                                                          .flat_map { |arm| arm.fetch("seeds") }.max
      end

      it "gives every child forty thousand epochs past its parent, at priority 40" do
        expect(definition.values_at(:epochs, :priority)).to eq([40_000, 40])
      end

      it "names the ladder in the engine's order" do
        expect(Lab::MetabolismReading::TASKS).to eq(Lab::Schema.tasks.fetch("ladder").pluck("name"))
        expect(Lab::MetabolismReading::TASKS & Lab::MetabolismReading::LOOP_TASKS)
          .to eq(Lab::MetabolismReading::LOOP_TASKS)
      end
    end

    describe "the logic sweep" do
      let(:definition) { Lab::SWEEPS.fetch("logic") }
      let(:treatments) { definition[:param_grid].fetch("treatment") }
      let(:metabolism) { Lab::SWEEPS.fetch("metabolism") }

      it "starts from the from-emerged sweep's parents under the same rule" do
        expect(definition[:parents]).to equal(Lab::SWEEPS.fetch("from_emerged")[:parents])
      end

      it "runs the full ladder, the deep rungs alone and no reward under one economy and assay" do
        full = { "energy_payer" => "initiator", "energy_influx" => 1024, "energy_stock_cap" => 65_536,
                 "steal_amount" => 0, "tasks" => "logic", "task_every" => 8, "task_reward" => 2048 }

        expect(treatments).to eq([full, full.merge("task_floor" => "xor"), full.merge("task_reward" => 0)])
      end

      it "sets only parameters the engine declares, each to a value it accepts" do
        treatments.flat_map(&:to_a).each do |name, value|
          field = Lab::Schema.field(name)
          if field["values"]
            expect(field["values"]).to include(value)
          else
            expect(value).to be_between(field["min"], field["max"])
          end
        end
      end

      it "names a deep-only floor on the logic ladder, at its first deep rung" do
        expect(Lab::LogicReading::DEEP_FLOOR).to eq(Lab::Schema.tasks.fetch("logic").fetch("first_deep"))
      end

      it "labels the two paid arms Metabolism runs and the unpaid arm fitness-free" do
        expect(treatments.map { |bundle| Lab::MetabolismReading.metabolism_run?(bundle) }).to eq([true, true, false])
        expect(treatments.map { |bundle| Lab::LogicReading.treatment_key(bundle) }).to eq(%i[full deep_only none])
      end

      # The engine holds `tasks = logic` at a reward of 0 to the run with tasks off, as it
      # holds `arith` there: the none child of a (parent, seed) is Metabolism's no-reward
      # child of it, world for world.
      it "repeats Metabolism's no-reward arm but for the assay its samples read" do
        none = treatments.last
        no_reward = metabolism[:param_grid].fetch("treatment").last

        expect(none.keys).to match_array(no_reward.keys)
        expect(none.reject { |key, value| no_reward[key] == value }).to eq("tasks" => "logic")
        expect(none.fetch("task_reward")).to eq(0)
        expect(definition.values_at(:parents, :seeds, :epochs)).to eq(metabolism.values_at(:parents, :seeds, :epochs))
      end

      it "changes no parameter that shapes the parent's world" do
        expect(treatments.flat_map(&:keys) & Lab::CanonicalParams::STRUCTURAL_KEYS).to be_empty
      end

      it "gives every child forty thousand epochs past its parent from seeds 2001–2003, at priority 40" do
        expect(definition.values_at(:seeds, :epochs, :priority)).to eq([[2001, 2002, 2003], 40_000, 40])
      end

      it "names the ladder in the engine's order" do
        expect(Lab::LogicReading::TASKS).to eq(Lab::Schema.logic_task_names)
        expect(Lab::LogicReading::TASKS.drop_while { |task| task != Lab::LogicReading::DEEP_FLOOR })
          .to eq(Lab::LogicReading::DEEP_TASKS)
        expect(Lab::LogicReading::TASKS & Lab::LogicReading::STEPPING_STONES).to eq(Lab::LogicReading::STEPPING_STONES)
      end
    end

    describe "the meta-stack sweep" do
      let(:definition) { Lab::SWEEPS.fetch("meta_stack") }
      let(:treatments) { definition[:param_grid].fetch("treatment") }
      let(:logic) { Lab::SWEEPS.fetch("logic") }
      let(:full) { logic[:param_grid].fetch("treatment").first }
      let(:meta) do
        { "meta_len" => 32, "meta_rate" => 0.00390625, "meta_draw" => "isa", "meta_seed" => "own_tape" }
      end

      it "starts from the from-emerged sweep's parents under the same rule, with Logic's seeds and budget" do
        expect(definition[:parents]).to equal(Lab::SWEEPS.fetch("from_emerged")[:parents])
        expect(definition.values_at(:parents, :seeds, :epochs, :priority))
          .to eq(logic.values_at(:parents, :seeds, :epochs, :priority))
        expect(definition.values_at(:seeds, :epochs, :priority)).to eq([[2001, 2002, 2003], 40_000, 40])
      end

      it "runs the stack, the stack paid from XOR up and the in-place NAND over Logic's full bundle and one tape" do
        expect(treatments).to eq([full.merge(meta, "logic_nand" => "stack"),
                                  full.merge(meta, "logic_nand" => "stack", "task_floor" => "xor"),
                                  full.merge(meta, "logic_nand" => "in_place")])
      end

      it "sets only parameters the engine declares, each to a value it accepts" do
        treatments.flat_map(&:to_a).each do |name, value|
          field = Lab::Schema.field(name)
          if field["values"]
            expect(field["values"]).to include(value)
          else
            expect(value).to be_between(field["min"], field["max"])
          end
        end
      end

      it "changes no parameter that shapes the parent's world" do
        expect(treatments.flat_map(&:keys) & Lab::CanonicalParams::STRUCTURAL_KEYS).to be_empty
      end

      it "labels every arm a Metabolism run" do
        expect(treatments.map { |bundle| Lab::MetabolismReading.metabolism_run?(bundle) }).to all(be(true))
      end

      it "keys its arms and the logic sweep's twins on the reward, the tape, the NAND and the floor" do
        expect(treatments.map { |bundle| Lab::MetaStackReading.treatment_key(bundle) })
          .to eq(%i[meta_stack meta_stack_deep_only meta_inplace])
        expect(logic[:param_grid].fetch("treatment").map { |bundle| Lab::MetaStackReading.treatment_key(bundle) })
          .to eq([:logic_full, nil, :logic_none])
        expect(Lab::MetaStackReading.treatment_key(full.merge(meta, "task_reward" => 0))).to be_nil
      end
    end

    describe "the topless-rise sweep" do
      let(:definition) { Lab::SWEEPS.fetch("topless_rise") }
      let(:treatments) { definition[:param_grid].fetch("treatment") }
      let(:reading) { Lab::ToplessRiseReading }

      it "starts from the meta-stack sweep's children of its meta-stack arm, unfloored or at the default floor" do
        expect(definition[:parents]).to include("experiment" => "meta-stack", "descendants" => true)
        expect(definition[:parents]["arms"].map { |arm| Lab::MetaStackReading.treatment_key(arm) })
          .to eq(%i[meta_stack meta_stack])
        expect(definition[:parents]["arms"].pluck("task_floor")).to eq([nil, "echo"])
      end

      it "runs one seed per parent a hundred thousand epochs past it at priority 40" do
        expect(definition.values_at(:seeds, :epochs, :priority)).to eq([[4001], 100_000, 40])
      end

      it "runs the four-input ladder paid by depth, the same capped at five NANDs, and no reward" do
        expect(treatments).to eq([{ "tasks" => "logic4", "task_reward" => 512 },
                                  { "tasks" => "logic4", "task_reward" => 512, "task_depth_cap" => 5 },
                                  { "tasks" => "logic4", "task_reward" => 0 }])
        expect(treatments.map { |bundle| reading.treatment_key(bundle) }).to eq(%i[rise capped none])
      end

      it "sets only parameters the engine declares, each to a value it accepts" do
        treatments.flat_map(&:to_a).each do |name, value|
          field = Lab::Schema.field(name)
          if field["values"]
            expect(field["values"]).to include(value)
          else
            expect(value).to be_between(field["min"], field["max"])
          end
        end
      end

      it "changes no parameter that shapes the parent's world" do
        expect(treatments.flat_map(&:keys) & Lab::CanonicalParams::STRUCTURAL_KEYS).to be_empty
      end

      it "pays no single rung up to the floor enough to saturate a cell holding ECHO, NOT and XOR beside it" do
        units = Lab::Schema.tasks.fetch("topless").fetch("depth_units")
        meta_stack = Lab::MetaStackReading::STACK_BUNDLE
        income = ->(paid) { meta_stack.fetch("energy_influx") + (reading::REWARD * paid / meta_stack.fetch("task_every")) }

        expect(income.call(1 + 1 + units[4] + units.last)).to be < Lab::Schema.run_defaults.fetch("max_steps")
      end

      it "ceilings a child at the depth the four-input table credits its open functions at" do
        expect(reading::CEILING_DEPTH).to eq(Lab::Schema.tasks.fetch("topless").fetch("depth_floor"))
      end

      it "reads depth on an observable the engine records" do
        expect(Sample::OBSERVABLES).to include(reading::DEPTH_KEY, reading::CLASSES_KEY)
      end

      it "names a seed no other sweep uses" do
        other_seeds = Lab::SWEEPS.except("topless_rise").values.flat_map { |sweep| Array(sweep[:seeds]) }

        expect(definition[:seeds] & other_seeds).to be_empty
      end
    end

    describe "the lineage-diversity sweep" do
      let(:definition) { Lab::SWEEPS.fetch("lineage_diversity") }
      let(:reading) { Lab::LineageDiversityReading }

      it "runs the radius sweep's arms at the rate that first produced emergence" do
        expect(definition[:param_grid].fetch("radius")).to eq(Lab::SWEEPS.fetch("radius")[:param_grid]["radius"])
        expect(definition[:param_grid].values_at("width", "height", "mutation_rate"))
          .to eq([[128], [128], [Lab::EMERGENT_MUTATION_RATE]])
      end

      it "holds tapes at a fixed 64 bytes" do
        expect(definition[:param_grid].values_at("tape_len", "max_tape_len")).to eq([[64], [64]])
      end

      it "inherits lineage tags through reverse copies" do
        expect(definition[:param_grid].fetch("lineage_rule")).to eq(["oriented"])
        expect(Lab::Schema.values_for("lineage_rule")).to include("oriented")
      end

      it "gives every arm ninety seeds of twenty thousand epochs, 360 runs in all" do
        expect(definition.values_at(:seeds, :epochs)).to eq([(1..90).to_a, 20_000])
        expect(definition[:param_grid].fetch("radius").size * definition[:seeds].size).to eq(360)
      end

      it "runs after the from-emerged children and ahead of sweep 9's extension" do
        expect(definition[:priority]).to be_between(1, Lab::SWEEPS.fetch("from_emerged")[:priority] - 1)
      end

      it "orders the trend test's arms from the well-mixed world to the shortest reach" do
        expect(reading::RADIUS_ORDER).to match_array(definition[:param_grid].fetch("radius"))
        expect(reading::RADIUS_ORDER).to eq([0, 4, 2, 1])
        expect(reading::MIN_READ_ARMS).to be_between(2, reading::RADIUS_ORDER.size)
      end

      it "reads polyphyly on an observable the engine records" do
        expect(Sample::OBSERVABLES).to include(reading::DIVERSITY_KEY, reading::SHARE_KEY, *reading::DESCRIPTIVE_KEYS)
        expect(reading::MONOPHYLETIC).to be < reading::POLYPHYLETIC
      end
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

    it "overrides the seeds of arms its own grid carries" do
      Lab::SWEEPS.each_value do |definition|
        points = grid_points(definition.fetch(:param_grid))

        arms(definition.fetch(:seeds_by_arm, {})).each do |arm|
          expect(points).to include(a_hash_including(arm))
        end
      end
    end

    # The builder gives a grid point the seeds of the first arm it matches, so two arms
    # sharing a point would hand the second its seeds silently.
    it "names no grid point by two arms" do
      Lab::SWEEPS.each_value do |definition|
        named = arms(definition.fetch(:seeds_by_arm, {}))

        grid_points(definition.fetch(:param_grid)).each do |point|
          expect(named.count { |arm| point >= arm }).to be <= 1
        end
      end
    end

    # Every arm an override names, as the parameters it must match, in either of the two
    # shapes Experiments::SweepBuilderService reads.
    def arms(seeds_by_arm)
      return seeds_by_arm.map { |arm| arm.fetch("params") } if seeds_by_arm.is_a?(Array)

      seeds_by_arm.flat_map { |name, seeds_by_value| seeds_by_value.keys.map { |value| { name => value } } }
    end

    def grid_points(param_grid)
      head, *tail = param_grid.map { |name, values| values.map { |value| value.is_a?(Hash) ? value : { name => value } } }
      head.product(*tail).map { |parts| parts.reduce({}, :merge) }
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
