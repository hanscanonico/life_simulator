# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Readings", type: :request do
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

  def reading(epoch, share: 0.5)
    { epoch: epoch, source_epoch: epoch - 5,
      values: { replicator_share: share, replicator_share_rotated: 0.0, dominant_self_replicates: true,
                reverse_copy_rate: 0.25 } }
  end

  def post_readings(readings, instrument: "oriented_census/1", headers: self.headers)
    post readings_api_run_path(run), params: { instrument: instrument, readings: readings },
                                     headers: headers, as: :json
  end

  describe "POST /api/runs/:id/readings" do
    it "stores the readings of an unclaimed finished run" do
      post_readings([reading(105), reading(205)])

      expect(response).to have_http_status(:no_content)
      expect(run.snapshot_readings.order(:epoch).pluck(:instrument, :epoch, :source_epoch))
        .to eq([["oriented_census/1", 105, 100], ["oriented_census/1", 205, 200]])
    end

    it "stores the engine's keys as the values" do
      post_readings([reading(105, share: 0.125)])

      expect(run.snapshot_readings.sole.values).to eq(
        "replicator_share" => 0.125, "replicator_share_rotated" => 0.0,
        "dominant_self_replicates" => true, "reverse_copy_rate" => 0.25
      )
    end

    it "overwrites a world read again rather than duplicating it" do
      post_readings([reading(105, share: 0.0)])
      post_readings([reading(105, share: 0.5)])

      expect(run.snapshot_readings.sole.values["replicator_share"]).to eq(0.5)
    end

    it "leaves the run's samples, metrics and status untouched" do
      run.update!(summary: { "replicator_count" => 3 })
      create(:sample, run: run, epoch: 100, values: { "replicator_count" => 3 })

      expect { post_readings([reading(105)]) }
        .not_to(change { [run.reload.attributes, run.samples.pluck(:epoch, :values)] })
    end

    it "accepts an empty list" do
      expect { post_readings([]) }.not_to change(SnapshotReading, :count)
      expect(response).to have_http_status(:no_content)
    end

    it "rejects a reading taken before its source world" do
      post_readings([reading(105).merge(source_epoch: 200)])

      expect(response).to have_http_status(:unprocessable_content)
      expect(SnapshotReading.count).to eq(0)
    end

    it "rejects a batch that names no instrument" do
      post readings_api_run_path(run), params: { readings: [reading(105)] }, headers: headers, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "answers not found for a run that does not exist" do
      post readings_api_run_path(id: 0), params: { instrument: "oriented_census/1", readings: [reading(105)] },
                                         headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a request with no token" do
      post_readings([reading(105)], headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(SnapshotReading.count).to eq(0)
    end
  end

  describe "GET /api/experiments/:slug/corpus" do
    before do
      create(:snapshot_reading, run: run, instrument: "oriented_census/1", epoch: 205, source_epoch: 200)
      create(:snapshot_reading, run: run, instrument: "oriented_census/1", epoch: 105, source_epoch: 100)
      create(:snapshot_reading, run: run, instrument: "other_census/1", epoch: 105, source_epoch: 100)
    end

    it "names the epochs each instrument has read" do
      get corpus_api_experiment_path(experiment.slug), headers: headers, as: :json

      expect(response.parsed_body["runs"].sole["read_epochs"])
        .to eq("oriented_census/1" => [105, 205], "other_census/1" => [105])
    end

    context "with an instrument named" do
      it "names only that instrument's epochs" do
        get corpus_api_experiment_path(experiment.slug, instrument: "oriented_census/1"), headers: headers

        expect(response.parsed_body["runs"].sole["read_epochs"]).to eq("oriented_census/1" => [105, 205])
      end
    end

    it "reads every run's read epochs in one query" do
      create(:snapshot_reading, run: create(:run, experiment: experiment, status: "failed"))

      queries = 0
      counter = ->(*, payload) { queries += 1 if payload[:sql].include?("snapshot_readings") }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get corpus_api_experiment_path(experiment.slug), headers: headers, as: :json
      end

      expect(queries).to eq(1)
    end
  end
end
