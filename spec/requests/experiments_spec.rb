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

    context "with no experiment" do
      it "still renders" do
        get experiments_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No experiment has been queued yet")
      end
    end
  end

  describe "GET /experiments/:slug" do
    it "draws the phase diagram and the runs table" do
      create(:run, experiment: experiment, seed: 7, status: "finished", transition_epoch: 900,
                   params: Lab::ENGINE_DEFAULTS.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Transition epoch vs radius", "<svg", "Runs")
    end

    context "with runs that never transitioned" do
      it "says so on the chart" do
        create(:run, experiment: experiment, status: "finished",
                     params: Lab::ENGINE_DEFAULTS.merge("radius" => 1))

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
