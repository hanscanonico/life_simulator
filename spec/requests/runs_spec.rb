# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Runs", type: :request do
  let(:run) { create(:run, seed: 4_242, epochs: 20_000, epochs_done: 20_000, transition_epoch: 900) }

  describe "GET /runs/:id" do
    it "shows the metric series, the seed and the parameters" do
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9, "copy_rate" => 0.0 })
      create(:sample, run: run, epoch: 900, values: { "compress_ratio" => 0.4, "copy_rate" => 0.31 })

      get run_path(run)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Compression ratio", "Copy rate", "<svg", "4242", "mutation_rate")
    end

    context "with no sample" do
      it "says the charts are empty instead of failing" do
        get run_path(run)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No samples recorded yet")
      end
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
