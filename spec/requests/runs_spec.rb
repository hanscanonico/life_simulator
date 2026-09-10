# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Runs", type: :request do
  let(:run) { create(:run, seed: 4_242, epochs: 20_000, epochs_done: 20_000, transition_epoch: 900) }

  describe "GET /runs/:id/samples.csv" do
    it "streams the whole metric series in epoch order" do
      create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4, "copy_rate" => 0.31 })
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      get samples_run_path(run, format: :csv)

      lines = response.body.lines.map(&:chomp)
      expect(response.media_type).to eq("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment", "run-#{run.id}-samples.csv")
      expect(lines.first).to eq("epoch,#{Sample::OBSERVABLES.join(',')}")
      expect(lines.second).to eq("100,0.9,,,,,,")
      expect(lines.third).to eq("200,0.4,,,,,,0.31")
    end

    context "with no sample" do
      it "still sends the header" do
        get samples_run_path(run, format: :csv)

        expect(response.body).to eq("epoch,#{Sample::OBSERVABLES.join(',')}\n")
      end
    end
  end

  describe "GET /runs/:id" do
    it "shows the metric series, the seed and the parameters" do
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9, "copy_rate" => 0.0 })
      create(:sample, run: run, epoch: 900, values: { "compress_ratio" => 0.4, "copy_rate" => 0.31 })

      get run_path(run)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Compression ratio", "Copy rate", "<svg", "4242", "mutation_rate")
    end

    it "draws one chart per observable of a run that reported samples" do
      create(:sample, run: run, epoch: 100, values: Runs::ShowPage::METRICS.keys.index_with(0.5))

      get run_path(run)

      expect(response.body.scan("chart-line").size).to eq(7)
    end

    context "with no sample" do
      it "says the run has not reported yet instead of drawing empty charts" do
        get run_path(run)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("This run has not reported a sample yet")
        expect(response.body).not_to include("No samples recorded yet")
      end
    end

    context "with a claimed run" do
      let(:run) { create(:run, :claimed, heartbeat_at: 2.minutes.ago) }

      it "dates the last heartbeat of the runner" do
        get run_path(run)

        expect(response.body).to include("runner-1", "last heartbeat 2 minutes ago")
      end
    end

    it "links the CSV of its samples" do
      get run_path(run)

      expect(response.body).to include("Download CSV", samples_run_path(run, format: :csv))
    end

    context "with snapshots" do
      it "links the PNG of each one" do
        snapshot = create(:snapshot, run: run, epoch: 500)

        get run_path(run)

        expect(response.body).to include(png_snapshot_path(snapshot))
      end
    end
  end
end
