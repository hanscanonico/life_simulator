# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:sweep" do
  describe "mutation_rate" do
    it "builds Experiment 1 of DESIGN 1.3: ten rates times ten seeds" do
      build_sweep("mutation_rate")

      expect(Experiment.find_by(slug: "mutation-rate").runs_count).to eq(100)
    end

    it "sweeps the rates DESIGN 1.3 names" do
      build_sweep("mutation_rate")

      expect(Run.distinct.pluck(Arel.sql("params->'mutation_rate'")).map(&:to_f).sort)
        .to eq([0.0, *(8..16).reverse_each.map { |exponent| 2.0**-exponent }])
    end

    it "resolves a run's parameters from the engine schema's defaults and the grid" do
      build_sweep("mutation_rate")

      expect(Run.order(:id).first.params)
        .to eq(Lab::Schema.run_defaults.merge("mutation_rate" => 0.0, "width" => 128, "height" => 128))
    end

    it "holds the world at 128 by 128" do
      build_sweep("mutation_rate")

      expect(Run.distinct.pluck(Arel.sql("params->'width'"), Arel.sql("params->'height'"))).to eq([[128, 128]])
    end

    it "gives every run the DESIGN epoch budget" do
      build_sweep("mutation_rate")

      expect(Run.distinct.pluck(:epochs)).to eq([20_000])
    end

    context "with the sweep already built" do
      it "creates no second copy" do
        build_sweep("mutation_rate")

        expect { build_sweep("mutation_rate") }.not_to change(Run, :count)
      end
    end
  end

  describe "world_size" do
    it "builds four square worlds times ten seeds" do
      build_sweep("world_size")

      expect(Experiment.find_by(slug: "world-size").runs_count).to eq(40)
    end

    it "resolves a run's parameters from the engine schema's defaults and the grid" do
      build_sweep("world_size")

      expect(Run.order(:id).first.params)
        .to eq(Lab::Schema.run_defaults.merge("width" => 32, "height" => 32))
    end

    it "keeps every world square" do
      build_sweep("world_size")

      expect(Run.pluck(:params).map { |params| params.values_at("width", "height") }.uniq.sort)
        .to eq([[32, 32], [64, 64], [128, 128], [256, 256]])
    end
  end

  describe "radius" do
    it "builds four neighbourhoods times ten seeds" do
      build_sweep("radius")

      expect(Experiment.find_by(slug: "radius").runs_count).to eq(40)
    end

    it "resolves a run's parameters from the engine schema's defaults and the grid" do
      build_sweep("radius")

      expect(Run.order(:id).first.params)
        .to eq(Lab::Schema.run_defaults.merge("radius" => 1, "width" => 128, "height" => 128))
    end
  end

  describe "max_steps" do
    it "builds four instruction budgets times ten seeds" do
      build_sweep("max_steps")

      expect(Experiment.find_by(slug: "max-steps").runs_count).to eq(40)
    end

    it "sweeps the budgets DESIGN 1.3 names" do
      build_sweep("max_steps")

      expect(Run.distinct.pluck(Arel.sql("params->'max_steps'")).sort).to eq([256, 1_024, 8_192, 65_536])
    end

    it "holds every run at the mutation rate that first produced emergence" do
      build_sweep("max_steps")

      expect(Run.distinct.pluck(Arel.sql("params->'mutation_rate'")).map(&:to_f)).to eq([2.0**-13])
    end

    it "resolves a run's parameters from the engine schema's defaults and the grid" do
      build_sweep("max_steps")

      expect(Run.order(:id).first.params)
        .to eq(Lab::Schema.run_defaults.merge("max_steps" => 256, "width" => 128, "height" => 128,
                                              "mutation_rate" => 2.0**-13))
    end
  end

  describe "ops" do
    it "builds the full instruction set and five ablations times ten seeds" do
      build_sweep("ops")

      expect(Experiment.find_by(slug: "ops").runs_count).to eq(60)
    end

    it "ablates one family of instructions per arm, from the full set" do
      build_sweep("ops")

      expect(Run.distinct.pluck(Arel.sql("params->>'ops'")).sort)
        .to eq(["<>+-.,[]", "<>{}+-.,", "<>{}+-.,[]", "<>{}+-.[]", "<>{}+-,[]", "<>{}.,[]"].sort)
    end

    it "resolves a run's parameters from the engine schema's defaults and the grid" do
      build_sweep("ops")

      expect(Run.order(:id).first.params)
        .to eq(Lab::Schema.run_defaults.merge("ops" => "<>{}+-.,[]", "width" => 128, "height" => 128,
                                              "mutation_rate" => 2.0**-13))
    end
  end

  describe "bff_control" do
    it "builds the two mutation arms times three seeds" do
      build_sweep("bff_control")

      expect(Experiment.find_by(slug: "bff-control").runs_count).to eq(6)
    end

    it "resolves a run's parameters from the engine schema's defaults and the grid" do
      build_sweep("bff_control")

      expect(Run.order(:id).first.params)
        .to eq(Lab::Schema.run_defaults.merge("mutation_rate" => 0.0, "width" => 512, "height" => 256,
                                              "radius" => 0, "sample_every" => 50, "snapshot_every" => 2_000))
    end

    it "gives the experiment and its runs the control's priority" do
      build_sweep("bff_control")

      expect(Experiment.find_by(slug: "bff-control").priority).to eq(10)
      expect(Run.distinct.pluck(:priority)).to eq([10])
    end

    it "gives every run the 50 000 epoch budget" do
      build_sweep("bff_control")

      expect(Run.distinct.pluck(:epochs)).to eq([50_000])
    end

    context "with the control already built" do
      it "creates no second copy" do
        build_sweep("bff_control")

        expect { build_sweep("bff_control") }.not_to change(Run, :count)
      end
    end

    context "with the hand-made control of the live lab already holding its runs" do
      before { hand_made_control }

      it "adopts the six runs it finds instead of queueing a second control" do
        expect { build_sweep("bff_control") }.not_to change(Run, :count)
        expect(Run.count).to eq(6)
      end

      it "leaves the sparse cadences of those runs alone" do
        build_sweep("bff_control")

        expect(Run.distinct.pluck(Arel.sql("params->'sample_every'"), Arel.sql("params->'snapshot_every'")))
          .to eq([[50, 2_000]])
      end
    end
  end

  # The bff-control runs of the live lab, built by hand before the sweep existed: they
  # predate the engine's `ops` parameter and carry the design record's sparse cadences.
  def hand_made_control
    experiment = create(:experiment, name: "BFF positive control", slug: "bff-control",
                                     epochs: 50_000, priority: 10, status: "running")
    params = { "width" => 512, "height" => 256, "tape_len" => 64, "radius" => 0, "max_steps" => 8_192,
               "init" => "random", "top_k" => 16, "sample_every" => 50, "snapshot_every" => 2_000 }

    [0.0, 2.0**-12].each do |rate|
      (1..3).each do |seed|
        create(:run, experiment: experiment, seed: seed, epochs: 50_000, priority: 10,
                     params: params.merge("mutation_rate" => rate))
      end
    end
  end

  it "refuses a sweep it does not know" do
    expect { build_sweep("colour") }.to raise_error(/Unknown sweep/)
  end

  def build_sweep(name)
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task["lab:sweep"]
    task.reenable
    original = $stdout
    $stdout = StringIO.new
    task.invoke(name)
  ensure
    $stdout = original
  end
end
