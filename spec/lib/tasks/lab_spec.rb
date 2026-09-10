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
