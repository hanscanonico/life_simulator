# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ShowPage do
  subject(:page) { described_class.build(experiment: experiment, paginate: paginate) }

  let(:paginate) { ->(scope) { [nil, scope.to_a] } }
  let(:experiment) do
    create(:experiment, epochs: 20_000, param_grid: { "radius" => [1, 2, 4], "width" => [128] })
  end

  def finished_run(radius:, transition_epoch: nil)
    create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch,
                 params: Lab::Schema.run_defaults.merge("radius" => radius))
  end

  describe "#axes" do
    it "sweeps only the grid keys with more than one value" do
      expect(page.axes.map(&:name)).to eq(["radius"])
    end

    context "with a paired grid value" do
      let(:experiment) do
        create(:experiment, param_grid: { "world_size" => [{ "width" => 32, "height" => 32 },
                                                           { "width" => 64, "height" => 64 }] })
      end

      it "reports the parameters the pair actually writes on a run" do
        expect(page.axes.sole.param_keys).to eq(%w[width height])
      end

      it "matches a run through the paired parameters" do
        run = create(:run, experiment: experiment, status: "finished", transition_epoch: 700,
                           params: Lab::Schema.run_defaults.merge("width" => 64, "height" => 64))

        group = page.diagrams.sole.groups.find { |candidate| candidate.label == "64" }

        expect(group.transition_epochs).to eq([run.transition_epoch])
      end
    end
  end

  describe "#diagrams" do
    context "with no run" do
      it "draws an empty diagram" do
        expect(page.diagrams.sole).to be_empty
      end
    end

    context "with runs that never transitioned" do
      it "counts them as censored" do
        finished_run(radius: 1)
        finished_run(radius: 1)

        group = page.diagrams.sole.groups.first

        expect(group).to have_attributes(censored: 2, transition_epochs: [])
      end
    end

    context "with a mix of transitions and censored runs" do
      it "groups the transition epochs by parameter value" do
        finished_run(radius: 1, transition_epoch: 100)
        finished_run(radius: 1, transition_epoch: 300)
        finished_run(radius: 2)
        create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 4))

        groups = page.diagrams.sole.groups

        expect(groups.map(&:transition_epochs)).to eq([[100, 300], [], []])
        expect(groups.map(&:censored)).to eq([0, 1, 0])
      end
    end

    context "with a grid spanning more than two decades" do
      let(:experiment) do
        create(:experiment, param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })
      end

      it "uses a log x axis" do
        expect(page.diagrams.sole.x_scale).to be_log
      end
    end
  end

  describe "#arms" do
    let(:experiment) do
      create(:experiment, epochs: 20_000, param_grid: { "radius" => [1, 2] })
    end

    it "is keyed by the axis the arms belong to" do
      expect(page.arms.keys.map(&:name)).to eq(["radius"])
    end

    context "with no finished run" do
      it "summarises every arm as empty" do
        create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 1))

        expect(page.arms.values.sole.map(&:runs_finished)).to eq([0, 0])
      end
    end

    context "with three transitions in one arm and two censored runs in the other" do
      before do
        finished_run(radius: 1, transition_epoch: 800)
        finished_run(radius: 1, transition_epoch: 100)
        finished_run(radius: 1, transition_epoch: 300)
        finished_run(radius: 2)
        finished_run(radius: 2)
      end

      it "summarises the arm that transitioned, quartiles interpolated" do
        arm = page.arms.values.sole.first

        expect(arm).to have_attributes(label: "1", runs_finished: 3, transitioned: 3, censored: 0,
                                       transition_fraction: 1.0, median_epoch: 300.0,
                                       q1_epoch: 200.0, q3_epoch: 550.0)
      end

      it "has no epoch for the arm in which nothing emerged" do
        arm = page.arms.values.sole.last

        expect(arm).to have_attributes(label: "2", runs_finished: 2, transitioned: 0, censored: 2,
                                       transition_fraction: 0.0, median_epoch: nil,
                                       q1_epoch: nil, q3_epoch: nil)
      end
    end
  end

  describe "#runs" do
    it "paginates the runs of the experiment" do
      run = finished_run(radius: 1, transition_epoch: 100)

      expect(page.runs).to eq([run])
    end
  end

  describe "#transition_rate" do
    it "is the share of finished runs that transitioned" do
      finished_run(radius: 1, transition_epoch: 100)
      finished_run(radius: 2)

      expect(page.transition_rate).to eq(0.5)
    end

    context "with no finished run" do
      it "has no rate" do
        expect(page.transition_rate).to be_nil
      end
    end
  end

  describe "#varying_keys" do
    it "lists the parameters the runs table has to show" do
      expect(page.varying_keys).to eq(["radius"])
    end
  end
end
