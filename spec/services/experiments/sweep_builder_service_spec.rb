# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::SweepBuilderService do
  subject(:build_sweep) { described_class.call(experiment) }

  let(:experiment) do
    create(:experiment, param_grid: { "mutation_rate" => [0.0, 0.5], "radius" => [1, 2] }, seeds: [1, 2, 3])
  end

  it "creates one run per parameter combination and seed" do
    expect { build_sweep }.to change(Run, :count).by(12)
  end

  it "resolves each run's parameters against the engine defaults" do
    build_sweep

    expect(experiment.runs.first.params).to eq(Lab::ENGINE_DEFAULTS.merge("mutation_rate" => 0.0, "radius" => 1))
  end

  it "gives every run the experiment's epoch budget" do
    build_sweep

    expect(experiment.runs.pluck(:epochs).uniq).to eq([experiment.epochs])
  end

  it "walks the grid in a deterministic order, seeds innermost" do
    build_sweep

    expect(experiment.runs.order(:id).limit(4).map { |run| [run.params["mutation_rate"], run.params["radius"], run.seed] })
      .to eq([[0.0, 1, 1], [0.0, 1, 2], [0.0, 1, 3], [0.0, 2, 1]])
  end

  it "queues the experiment" do
    build_sweep

    expect(experiment).to be_queued
  end

  context "with the sweep already built" do
    it "does not duplicate its runs" do
      build_sweep

      expect { described_class.call(experiment.reload) }.not_to change(Run, :count)
    end
  end

  context "with an axis whose values are parameter bundles" do
    let(:experiment) do
      create(:experiment, param_grid: { "world_size" => [{ "width" => 32, "height" => 32 },
                                                         { "width" => 64, "height" => 64 }] }, seeds: [1])
    end

    it "applies every parameter of the bundle to the same run" do
      build_sweep

      expect(experiment.runs.order(:id).map { |run| run.params.slice("width", "height") })
        .to eq([{ "width" => 32, "height" => 32 }, { "width" => 64, "height" => 64 }])
    end
  end

  context "with an empty grid" do
    let(:experiment) { create(:experiment, param_grid: {}, seeds: [1, 2]) }

    it "creates one default run per seed" do
      build_sweep

      expect(experiment.runs.pluck(:params).uniq).to eq([Lab::ENGINE_DEFAULTS])
    end
  end
end
