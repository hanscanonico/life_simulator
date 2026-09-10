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
                   params: Lab::Schema.run_defaults.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Transition epoch vs radius", "<svg", "Runs")
      expect(response.body).to include("Download CSV", experiment_path(experiment, format: :csv))
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

    context "as CSV" do
      it "streams one row per run with its seed and its swept parameters" do
        create(:run, experiment: experiment, seed: 7, status: "finished", epochs: 20_000, epochs_done: 20_000,
                     transition_epoch: 900, params: Lab::Schema.run_defaults.merge("radius" => 2),
                     summary: { "compress_ratio" => 0.42 })
        create(:run, experiment: experiment, seed: 8, status: "finished", epochs: 20_000, epochs_done: 20_000,
                     params: Lab::Schema.run_defaults.merge("radius" => 4))

        get experiment_path(experiment, format: :csv)

        lines = response.body.lines.map(&:chomp)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment", "radius-runs.csv")
        expect(lines.first).to eq("run_id,seed,status,epochs,epochs_done,transition_epoch,radius,#{Sample::OBSERVABLES.join(',')}")
        expect(lines.size).to eq(3)
        expect(lines.second).to include(",7,finished,20000,20000,900,2,0.42")
        expect(lines.third).to include(",8,finished,20000,20000,,4,")
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
