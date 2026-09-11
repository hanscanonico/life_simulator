# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Rescores", type: :request do
  let(:token) { "s3cret-runner-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:experiment) { create(:experiment, slug: "radius-sweep") }
  let(:run) { create(:run, experiment: experiment, status: "finished", seed: 7, transition_epoch: 400) }

  around do |example|
    previous = ENV.fetch("RUNNER_TOKEN", nil)
    ENV["RUNNER_TOKEN"] = token
    example.run
    ENV["RUNNER_TOKEN"] = previous
  end

  def reading(top_k:, replicator_count:)
    { epoch: 100, top_k: top_k, replicator_count: replicator_count, top_share: 0.5,
      distinct_tapes: 12, compress_ratio: 0.25, entropy_bits: 3.5 }
  end

  describe "GET /api/experiments/:slug/corpus" do
    it "names the terminal runs and the worlds they stored" do
      create(:snapshot, run: run, epoch: 300)
      create(:snapshot, run: run, epoch: 100)
      create(:snapshot, run: run, epoch: 200, blob: nil)

      get corpus_api_experiment_path(experiment.slug), headers: headers, as: :json

      expect(response.parsed_body).to eq(
        "slug" => "radius-sweep",
        "runs" => [{ "id" => run.id, "seed" => 7, "params" => run.params, "status" => "finished",
                     "transition_epoch" => 400, "epochs" => [100, 300] }]
      )
    end

    it "leaves out the runs still to finish" do
      run
      create(:run, experiment: experiment, status: "running")

      get corpus_api_experiment_path(experiment.slug), headers: headers, as: :json

      expect(response.parsed_body["runs"].pluck("status")).to eq(["finished"])
    end

    it "reads every run's epochs in one query" do
      other = create(:run, experiment: experiment, status: "failed")
      create(:snapshot, run: run, epoch: 100)
      create(:snapshot, run: other, epoch: 100)

      queries = 0
      counter = ->(*, payload) { queries += 1 if payload[:sql].include?("snapshots") }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get corpus_api_experiment_path(experiment.slug), headers: headers, as: :json
      end

      expect(queries).to eq(1)
    end

    it "answers not found for an experiment that does not exist" do
      get corpus_api_experiment_path("nope"), headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a request with no token" do
      get corpus_api_experiment_path(experiment.slug), as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/runs/:id/rescores" do
    it "stores a reading per top_k" do
      post rescores_api_run_path(run),
           params: { rescores: [reading(top_k: 16, replicator_count: 0), reading(top_k: 64, replicator_count: 38)] },
           headers: headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(run.rescores.order(:top_k).pluck(:top_k, :replicator_count)).to eq([[16, 0], [64, 38]])
    end

    it "records what the reading measured" do
      post rescores_api_run_path(run), params: { rescores: [reading(top_k: 16, replicator_count: 2)] },
                                       headers: headers, as: :json

      expect(run.rescores.sole).to have_attributes(epoch: 100, top_share: 0.5, distinct_tapes: 12,
                                                   compress_ratio: 0.25, entropy_bits: 3.5,
                                                   measured_at: be_present)
    end

    it "updates a reading rather than duplicating it" do
      post rescores_api_run_path(run), params: { rescores: [reading(top_k: 16, replicator_count: 0)] },
                                       headers: headers, as: :json
      post rescores_api_run_path(run), params: { rescores: [reading(top_k: 16, replicator_count: 5)] },
                                       headers: headers, as: :json

      expect(run.rescores.sole.replicator_count).to eq(5)
    end

    it "accepts an empty batch" do
      post rescores_api_run_path(run), params: { rescores: [] }, headers: headers, as: :json

      expect(response).to have_http_status(:no_content)
    end

    it "rejects a request with no token" do
      post rescores_api_run_path(run), params: { rescores: [] }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
