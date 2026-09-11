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

    it "names the substrate beside the sweep instead of a dangling dash" do
      get run_path(run)

      expect(response.body).to include("soup substrate, seed")
      expect(response.body).not_to match(/—\s*\n?\s*seed/)
    end

    context "with a run of a neighbourhood sweep" do
      let(:experiment) { create(:experiment, name: "Neighbourhood radius", param_grid: { "radius" => [0, 1, 2] }) }
      let(:run) { create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 0)) }

      it "names the arm the sweep's tables name, well-mixed included" do
        get run_path(run)

        expect(response.body).to include("well-mixed, soup substrate, seed")
      end

      context "with a run off the grid" do
        let(:run) { create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 7)) }

        it "names the run's own value" do
          get run_path(run)

          expect(response.body).to include("7, soup substrate, seed")
        end
      end
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

    context "with a run that reported samples over time" do
      let(:run) { create(:run, :claimed, epochs: 20_000, epochs_done: 1_000) }

      it "reads the rate and the time remaining off the samples' own clock" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 100, created_at: recorded_at - 10.seconds)
        create(:sample, run: run, epoch: 200, created_at: recorded_at)

        get run_path(run)

        expect(response.body.squish).to include("measured from recorded samples", "10.0 epochs/s",
                                                "Time remaining", "32 minutes")
      end
    end

    context "with a run that has no measurable rate" do
      it "dashes both rows instead of guessing" do
        get run_path(run)

        expect(response.body.squish).to match(/Rate.*—.*Time remaining.*—/)
      end
    end

    context "with a sweep a finding rests on" do
      let(:experiment) { create(:experiment, name: "Mutation rate", slug: "mutation-rate") }
      let(:run) { create(:run, experiment: experiment, seed: 1) }

      it "cites the write-up with its status" do
        finding = Findings::Registry.find("mutation-rate-window")

        get run_path(run)

        expect(response.body.squish).to include("Cited by:", finding.title, finding.status_label)
        expect(response.body).to include(finding_path(finding))
      end
    end

    context "with a sweep no finding cites" do
      it "says nothing about citations" do
        get run_path(create(:run, experiment: create(:experiment, slug: "nobody-cites-this")))

        expect(response.body).not_to include("Cited by")
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
