# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Runs", type: :request do
  let(:token) { "s3cret-runner-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:experiment) { create(:experiment, status: "queued") }

  around do |example|
    previous = ENV.fetch("RUNNER_TOKEN", nil)
    ENV["RUNNER_TOKEN"] = token
    example.run
    ENV["RUNNER_TOKEN"] = previous
  end

  describe "authentication" do
    # The bearer token guards the whole API, so every endpoint is checked: an
    # `authenticate_runner!` narrowed to one action would leave the rest wide open.
    let(:run) { create(:run, :claimed, experiment: experiment) }
    let(:requests) do
      { "claim" => ->(sent) { post claim_api_runs_path, params: { runner_id: "runner-1" }, headers: sent, as: :json },
        "heartbeat" => lambda { |sent|
          post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 1 }, headers: sent, as: :json
        },
        "samples" => lambda { |sent|
          post samples_api_run_path(run), params: { runner_id: "runner-1", samples: [] }, headers: sent, as: :json
        },
        "snapshots" => lambda { |sent|
          post snapshots_api_run_path(run), params: { runner_id: "runner-1", epoch: 1 }, headers: sent, as: :json
        },
        "finish" => lambda { |sent|
          post finish_api_run_path(run), params: { runner_id: "runner-1" }, headers: sent, as: :json
        },
        "latest_snapshot" => lambda { |sent|
          get latest_snapshot_api_run_path(run), params: { runner_id: "runner-1" }, headers: sent, as: :json
        },
        "world" => ->(sent) { get world_api_run_path(run), headers: sent, as: :json } }
    end

    %w[claim heartbeat samples snapshots finish latest_snapshot world].each do |endpoint|
      context "for #{endpoint}" do
        it "rejects a request with no token" do
          requests.fetch(endpoint).call({})

          expect(response).to have_http_status(:unauthorized)
        end

        it "rejects a request with the wrong token" do
          requests.fetch(endpoint).call("Authorization" => "Bearer nope")

          expect(response).to have_http_status(:unauthorized)
        end

        context "with no token configured" do
          it "rejects the request rather than standing open" do
            ENV["RUNNER_TOKEN"] = nil

            requests.fetch(endpoint).call(headers)

            expect(response).to have_http_status(:unauthorized)
          end
        end
      end
    end
  end

  describe "POST /api/runs/claim" do
    it "hands the oldest pending run to the runner" do
      run = create(:run, experiment: experiment, seed: 7, epochs: 20_000)

      post claim_api_runs_path, params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(response.parsed_body).to eq("id" => run.id, "params" => run.params, "seed" => 7,
                                         "epochs" => 20_000, "epochs_done" => 0)
    end

    it "marks the run claimed" do
      run = create(:run, experiment: experiment)

      post claim_api_runs_path, params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(run.reload).to have_attributes(status: "claimed", runner_id: "runner-1")
    end

    it "releases a silent run before claiming" do
      stale = create(:run, :stale, experiment: experiment)

      post claim_api_runs_path, params: { runner_id: "runner-2" }, headers: headers, as: :json

      expect(stale.reload.runner_id).to eq("runner-2")
    end

    context "with an empty queue" do
      it "answers no content" do
        post claim_api_runs_path, params: { runner_id: "runner-1" }, headers: headers, as: :json

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe "POST /api/runs/:id/heartbeat" do
    let(:run) { create(:run, :claimed, experiment: experiment, heartbeat_at: 1.minute.ago) }

    it "records the progress the runner reports" do
      post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 500 }, headers: headers, as: :json

      expect(run.reload).to have_attributes(status: "running", epochs_done: 500, started_at: be_present)
    end

    it "refreshes the heartbeat" do
      expect { post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 500 }, headers: headers }
        .to(change { run.reload.heartbeat_at })
    end

    it "rejects a runner that does not hold the run" do
      post heartbeat_api_run_path(run), params: { runner_id: "runner-9", epochs_done: 500 }, headers: headers, as: :json

      expect(response).to have_http_status(:conflict)
    end

    it "answers not found for an unknown run" do
      post heartbeat_api_run_path(id: 0), params: { runner_id: "runner-1", epochs_done: 1 }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "never lowers the progress already reported" do
      run.update!(epochs_done: 800)

      post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 500 }, headers: headers, as: :json

      expect(run.reload.epochs_done).to eq(800)
    end

    it "stamps the moment the progress moved" do
      run.update!(epochs_done: 400, epochs_done_at: 20.minutes.ago)

      post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 500 }, headers: headers, as: :json

      expect(run.reload.epochs_done_at).to be_within(1.minute).of(Time.current)
    end

    context "with a heartbeat reporting the progress already stored" do
      it "leaves the stamp where it was, so a wedged run stays visible" do
        run.update!(epochs_done: 500, epochs_done_at: 20.minutes.ago)

        post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 500 }, headers: headers,
                                          as: :json

        expect(run.reload.epochs_done_at).to be_within(1.minute).of(20.minutes.ago)
      end
    end

    context "with a heartbeat that lands after the run finished" do
      let(:run) do
        create(:run, :claimed, experiment: experiment, status: "finished", epochs_done: 1_000,
                               finished_at: 1.minute.ago)
      end

      it "accepts the late heartbeat without complaining to the runner" do
        post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 900 }, headers: headers,
                                          as: :json

        expect(response).to have_http_status(:no_content)
      end

      it "leaves the finished run alone" do
        post heartbeat_api_run_path(run), params: { runner_id: "runner-1", epochs_done: 900 }, headers: headers,
                                          as: :json

        expect(run.reload).to have_attributes(status: "finished", epochs_done: 1_000, finished_at: be_present)
      end
    end
  end

  describe "POST /api/runs/:id/samples" do
    let(:run) { create(:run, :claimed, experiment: experiment) }
    let(:payload) do
      { runner_id: "runner-1",
        samples: [{ epoch: 100, compress_ratio: 0.99 }, { epoch: 200, compress_ratio: 0.55 }] }
    end

    it "stores one row per sampled epoch" do
      post samples_api_run_path(run), params: payload, headers: headers, as: :json

      expect(run.samples.order(:epoch).pluck(:epoch)).to eq([100, 200])
    end

    it "keeps the metrics as data" do
      post samples_api_run_path(run), params: payload, headers: headers, as: :json

      expect(run.samples.order(:epoch).last.values).to eq("compress_ratio" => 0.55)
    end

    it "summarises the run with the last sample" do
      post samples_api_run_path(run), params: payload, headers: headers, as: :json

      expect(run.reload.summary).to eq("compress_ratio" => 0.55)
    end

    it "records the transition epoch the payload carries" do
      post samples_api_run_path(run), params: payload.merge(transition_epoch: 200), headers: headers, as: :json

      expect(run.reload.transition_epoch).to eq(200)
    end

    context "with a batch the runner already posted" do
      it "stores no duplicate rows" do
        post samples_api_run_path(run), params: payload, headers: headers, as: :json

        expect { post samples_api_run_path(run), params: payload, headers: headers, as: :json }
          .not_to change(Sample, :count)
      end
    end

    it "rejects a runner that does not hold the run" do
      post samples_api_run_path(run), params: payload.merge(runner_id: "runner-9"), headers: headers, as: :json

      expect(response).to have_http_status(:conflict)
    end
  end

  describe "POST /api/runs/:id/snapshots" do
    let(:run) { create(:run, :claimed, experiment: experiment) }

    it "stores a base64 payload" do
      post snapshots_api_run_path(run),
           params: { runner_id: "runner-1", epoch: 300, blob: Base64.encode64("world"), png: Base64.encode64("png") },
           headers: headers, as: :json

      expect(run.snapshots.sole).to have_attributes(epoch: 300, blob: "world", png: "png")
    end

    it "stores an uploaded payload" do
      post snapshots_api_run_path(run),
           params: { runner_id: "runner-1", epoch: 300, blob: upload("world"), png: upload("png") },
           headers: headers

      expect(run.snapshots.sole.blob).to eq("world")
    end

    it "replaces the snapshot already held for that epoch" do
      create(:snapshot, run: run, epoch: 300, blob: "old")

      post snapshots_api_run_path(run),
           params: { runner_id: "runner-1", epoch: 300, blob: Base64.encode64("new") }, headers: headers, as: :json

      expect(run.snapshots.sole.blob).to eq("new")
    end

    it "stores a world the size of the programme's largest" do
      post snapshots_api_run_path(run),
           params: { runner_id: "runner-1", epoch: 300, blob: upload("w" * 8.megabytes) }, headers: headers

      expect(run.snapshots.sole.blob.bytesize).to eq(8.megabytes)
    end

    # The cap itself is 64 MiB; posting that much through the rack stack for an example
    # buys nothing the model spec does not already pin, so only the 422 wiring is checked.
    context "with a payload over the cap" do
      it "answers unprocessable content and stores nothing" do
        stub_const("Snapshot::MAX_BYTES", 8)

        post snapshots_api_run_path(run),
             params: { runner_id: "runner-1", epoch: 300, blob: Base64.encode64("w" * 9) },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(run.snapshots).to be_empty
      end
    end

    # A runner resumed over a deploy can still be the pre-reason build, and its snapshots
    # are cadence ones.
    it "stores a payload posted without a reason as a cadence snapshot" do
      post snapshots_api_run_path(run),
           params: { runner_id: "runner-1", epoch: 300, blob: Base64.encode64("world") },
           headers: headers, as: :json

      expect(run.snapshots.sole.reason).to eq("cadence")
    end

    it "stores every reason the run loop gives" do
      Snapshot::REASONS.each_with_index do |reason, index|
        post snapshots_api_run_path(run),
             params: { runner_id: "runner-1", epoch: 300 + index, blob: Base64.encode64("world"),
                       reason: reason },
             headers: headers, as: :json
      end

      expect(run.snapshots.order(:epoch).pluck(:reason)).to eq(Snapshot::REASONS)
    end

    context "with a reason the run loop cannot give" do
      it "answers unprocessable content and stores nothing" do
        post snapshots_api_run_path(run),
             params: { runner_id: "runner-1", epoch: 300, blob: Base64.encode64("world"), reason: "whim" },
             headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(run.snapshots).to be_empty
      end
    end

    it "rejects a runner that does not hold the run" do
      post snapshots_api_run_path(run), params: { runner_id: "runner-9", epoch: 300 }, headers: headers, as: :json

      expect(response).to have_http_status(:conflict)
    end
  end

  describe "GET /api/runs/:id/snapshots/latest" do
    let(:run) { create(:run, :claimed, experiment: experiment) }

    it "hands back the newest world the run snapshotted" do
      create(:snapshot, run: run, epoch: 100, blob: "old")
      create(:snapshot, run: run, epoch: 300, blob: "newest")

      get latest_snapshot_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(response.parsed_body).to eq("epoch" => 300, "blob" => Base64.strict_encode64("newest"))
    end

    it "omits the png the runner has no use for, keeping the answer small" do
      create(:snapshot, run: run, epoch: 300, blob: "newest", png: "a png the runner never restores")

      get latest_snapshot_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(response.parsed_body.keys).to contain_exactly("epoch", "blob")
    end

    it "ignores a snapshot with no world bytes to restore" do
      create(:snapshot, run: run, epoch: 100, blob: "restorable")
      create(:snapshot, run: run, epoch: 300, blob: nil)

      get latest_snapshot_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(response.parsed_body["epoch"]).to eq(100)
    end

    context "with no snapshot yet" do
      it "answers no content, so the runner starts the run fresh" do
        get latest_snapshot_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

        expect(response).to have_http_status(:no_content)
      end
    end

    it "rejects a runner that does not hold the run" do
      get latest_snapshot_api_run_path(run), params: { runner_id: "runner-9" }, headers: headers, as: :json

      expect(response).to have_http_status(:conflict)
    end

    # A resumed run restarts at whatever epoch the answer names, so the two content types
    # must agree on it: DESIGN §2, "a claimed run resumes from its latest snapshot".
    describe "content types" do
      before { create(:snapshot, run: run, epoch: 300, blob: "newest") }

      it "carries the epoch and the base64 blob as json" do
        get latest_snapshot_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

        expect(response.parsed_body).to eq("epoch" => 300, "blob" => Base64.strict_encode64("newest"))
      end

      it "carries the epoch in a header and the blob as bytes as octet-stream" do
        get latest_snapshot_api_run_path(run),
            params: { runner_id: "runner-1" },
            headers: headers.merge("Accept" => "application/octet-stream")

        expect(response.media_type).to eq("application/octet-stream")
        expect(response.headers["X-Snapshot-Epoch"]).to eq("300")
        expect(response.body).to eq("newest")
      end
    end
  end

  describe "GET /api/runs/:id/world" do
    let(:run) { create(:run, experiment: experiment, status: "finished", seed: 7) }

    it "hands back the newest stored world with the params that describe it" do
      create(:snapshot, run: run, epoch: 100, blob: "old")
      create(:snapshot, run: run, epoch: 300, blob: "newest")

      get world_api_run_path(run), headers: headers, as: :json

      expect(response.parsed_body).to eq("id" => run.id, "params" => run.params, "seed" => 7,
                                         "epoch" => 300, "blob" => Base64.strict_encode64("newest"))
    end

    it "hands back the world of the epoch asked for" do
      create(:snapshot, run: run, epoch: 100, blob: "old")
      create(:snapshot, run: run, epoch: 300, blob: "newest")

      get world_api_run_path(run), params: { epoch: 100 }, headers: headers, as: :json

      expect(response.parsed_body.values_at("epoch", "blob")).to eq([100, Base64.strict_encode64("old")])
    end

    it "ignores a snapshot with no world bytes to read" do
      create(:snapshot, run: run, epoch: 100, blob: "readable")
      create(:snapshot, run: run, epoch: 300, blob: nil)

      get world_api_run_path(run), headers: headers, as: :json

      expect(response.parsed_body["epoch"]).to eq(100)
    end

    context "with no snapshot at that epoch" do
      it "answers no content" do
        get world_api_run_path(run), params: { epoch: 42 }, headers: headers, as: :json

        expect(response).to have_http_status(:no_content)
      end
    end

    # A rescore reads runs nobody is running, so this endpoint is the one the runner
    # reaches without holding the run.
    it "serves a run no runner holds" do
      create(:snapshot, run: run, epoch: 300, blob: "newest")

      get world_api_run_path(run), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/runs/:id/finish" do
    let(:run) { create(:run, :claimed, experiment: experiment) }

    it "finishes the run" do
      post finish_api_run_path(run),
           params: { runner_id: "runner-1", transition_epoch: 4_200, summary: { compress_ratio: 0.31 } },
           headers: headers, as: :json

      expect(run.reload).to have_attributes(status: "finished", transition_epoch: 4_200,
                                            summary: { "compress_ratio" => 0.31 })
    end

    it "credits the finished run with its whole epoch budget" do
      run.update!(epochs: 20_000, epochs_done: 19_342)

      post finish_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(run.reload.epochs_done).to eq(20_000)
    end

    it "finishes the experiment once every run is terminal" do
      post finish_api_run_path(run), params: { runner_id: "runner-1" }, headers: headers, as: :json

      expect(experiment.reload).to be_finished
    end

    context "with an error reported" do
      it "fails the run" do
        post finish_api_run_path(run), params: { runner_id: "runner-1", error: "engine panicked" }, headers: headers, as: :json

        expect(run.reload).to have_attributes(status: "failed", error: "engine panicked")
      end
    end

    it "rejects a runner that does not hold the run" do
      post finish_api_run_path(run), params: { runner_id: "runner-9" }, headers: headers, as: :json

      expect(response).to have_http_status(:conflict)
    end
  end

  def upload(content)
    file = Tempfile.new("snapshot")
    file.binmode
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/octet-stream")
  end
end
