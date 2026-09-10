# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Experiments", type: :request do
  let(:experiment) do
    create(:experiment, name: "Neighbourhood radius", slug: "radius", epochs: 20_000,
                        param_grid: { "radius" => [1, 2, 4] })
  end

  describe "GET /experiments" do
    it "lists the sweeps with their transition rate" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 900)
      create(:run, experiment: experiment, status: "finished")

      get experiments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Neighbourhood radius", "50%")
    end

    it "lists the sweeps of the programme that are not queued yet" do
      experiment

      get experiments_path

      expect(response.body).to include("Not queued yet", "Instruction set ablations")
      expect(response.body).not_to include("Neighbourhood radius</dt>")
    end

    context "with no experiment" do
      it "still renders, pointing at the planned programme" do
        get experiments_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No sweep has been queued yet", "Mutation rate")
      end
    end
  end

  describe "GET /experiments/:slug" do
    it "draws the phase diagram and the runs table" do
      create(:run, experiment: experiment, seed: 7, status: "finished", transition_epoch: 900,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Transition epoch vs radius", "<svg", "Runs")
    end

    it "spells the transition rate out over the finished runs alone" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))
      create(:run, experiment: experiment, status: "finished",
                   params: Lab::Schema.run_defaults.merge("radius" => 4))
      create(:run, experiment: experiment, status: "running", transition_epoch: 300,
                   params: Lab::Schema.run_defaults.merge("radius" => 1))

      get experiment_path(experiment)

      expect(response.body).to include("1 of 2 finished runs transitioned", "50%",
                                       "+1 run still under way already transitioned")
    end

    it "shows each run's queue priority" do
      create(:run, experiment: experiment, priority: 5)

      get experiment_path(experiment)

      expect(response.body).to include("Priority", %(<td class="numeric">5</td>))
    end

    it "summarises every arm of the sweep" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))
      create(:run, experiment: experiment, status: "finished",
                   params: Lab::Schema.run_defaults.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response.body).to include("Arms of radius", "Median epoch", "IQR", "1/2")
    end

    context "with a sweep no run of which has finished" do
      it "shows no arm table" do
        create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 1))

        get experiment_path(experiment)

        expect(response.body).not_to include("Arms of radius")
      end
    end

    context "with runs that never transitioned" do
      it "says so on the chart" do
        create(:run, experiment: experiment, status: "finished",
                     params: Lab::Schema.run_defaults.merge("radius" => 1))

        get experiment_path(experiment)

        expect(response.body).to include("no emergence in 20000 epochs")
      end
    end

    context "with more runs than a page holds" do
      it "paginates them" do
        create_list(:run, 26, experiment: experiment)

        get experiment_path(experiment)

        expect(response.body).to include("series-nav")
      end
    end

    it "is addressed by slug" do
      experiment

      get "/experiments/radius"

      expect(response).to have_http_status(:ok)
    end

    context "with an unknown slug" do
      it "is a 404" do
        get "/experiments/nope"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
