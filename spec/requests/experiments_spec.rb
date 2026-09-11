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

    it "frames the page for a browser and a crawler" do
      get experiments_path

      expect(response.body).to include('<html lang="en">', "<title>Experiments — Life Simulator</title>",
                                       '<meta property="og:type" content="website">')
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
      expect(response.body).to include("Download CSV", experiment_path(experiment, format: :csv))
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

    it "names each run's arm the way the diagram and the arm table do" do
      experiment.update!(param_grid: { "radius" => [1, 2, 0] })
      create(:run, experiment: experiment, seed: 3, params: Lab::Schema.run_defaults.merge("radius" => 0))

      get experiment_path(experiment)

      expect(response.body).to include(%(<td class="numeric mono">well-mixed</td>))
    end

    it "shows each run's queue priority" do
      create(:run, experiment: experiment, priority: 5)

      get experiment_path(experiment)

      expect(response.body).to include("Priority", %(<td class="numeric">5</td>))
    end

    it "delimits each run's transition epoch and dashes the runs without one" do
      create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, transition_epoch: 12_345,
                   params: Lab::Schema.run_defaults.merge("radius" => 1))
      create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response.body).to include(%(<td class="numeric">12,345</td>))
      expect(response.body).to match(%r{<td class="numeric">20,000</td>\s*<td class="numeric">—</td>})
    end

    it "summarises every arm of the sweep" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))
      create(:run, experiment: experiment, status: "finished",
                   params: Lab::Schema.run_defaults.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response.body).to include("Arms of radius", "Median epoch", "IQR")
      expect(response.body).to match(%r{<span class="mono">1/2</span>\s*<span class="text-muted">\s*50%})
      expect(response.body).to match(%r{<span class="mono">0/0</span>\s*<span class="text-muted">\s*—})
    end

    context "with samples behind the finished runs" do
      before do
        flagged = create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                               params: Lab::Schema.run_defaults.merge("radius" => 2))
        create(:sample, run: flagged, epoch: 900,
                        values: { "compress_ratio" => 0.4, "replicator_count" => 6 })
        unflagged = create(:run, experiment: experiment, status: "finished",
                                 params: Lab::Schema.run_defaults.merge("radius" => 2))
        create(:sample, run: unflagged, epoch: 900,
                        values: { "compress_ratio" => 0.98, "replicator_count" => 0 })
      end

      it "reconciles the detector with the replicator census, arm by arm" do
        get experiment_path(experiment)

        expect(response.body).to include("Detector against replicator census", "Either but not both")
        expect(response.body).to match(
          %r{<td class="mono">2</td>\s*<td class="numeric">2</td>\s*<td class="numeric">1</td>}
        )
      end

      it "offers the transition report beside the runs CSV" do
        get experiment_path(experiment)

        expect(response.body).to include("Download transition report (CSV)",
                                         transitions_experiment_path(experiment))
      end

      it "streams the transition report as CSV" do
        get transitions_experiment_path(experiment)

        lines = response.body.lines.map(&:chomp)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment", "radius-transitions.csv")
        expect(lines).to include("arm,n,flagged,replicators,both,either_but_not_both", "2,2,1,1,1,0")
      end
    end

    context "with a sweep nothing has been sampled from" do
      it "shows no transition report" do
        create(:run, experiment: experiment, status: "finished",
                     params: Lab::Schema.run_defaults.merge("radius" => 2))

        get experiment_path(experiment)

        expect(response.body).not_to include("Detector against replicator census",
                                             "Download transition report (CSV)")
      end
    end

    context "with censored runs alongside runs that emerged" do
      before do
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, transition_epoch: 900,
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
        live = create(:run, :claimed, experiment: experiment, epochs_done: 0,
                                      params: Lab::Schema.run_defaults.merge("radius" => 4))
        create(:sample, run: live, epoch: 5_000)
      end

      it "draws the survival curves under the phase diagram" do
        get experiment_path(experiment)

        expect(response.body).to include("Time to emergence vs radius", "P(no emergence)",
                                         "stroke-dasharray", "2 — 1 of 2 emerged", "4 — 0 of 1 emerged")
      end

      it "tabulates the hazard per arm and pooled over the sweep" do
        get experiment_path(experiment)

        # 1 event over 900 + 20 000 + 5 000 run-epochs at risk: 0.386 per 10^4 epochs.
        expect(response.body).to include("Emergence hazard per arm of radius", "Run-epochs at risk",
                                         "All arms", "25,900", "0.386")
      end
    end

    context "with a sweep no run of which has finished" do
      it "shows no arm table" do
        create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 1))

        get experiment_path(experiment)

        expect(response.body).not_to include("Arms of radius")
      end

      it "says the rate has no denominator yet" do
        create(:run, experiment: experiment, status: "running", transition_epoch: 300,
                     params: Lab::Schema.run_defaults.merge("radius" => 1))

        get experiment_path(experiment)

        expect(response.body).to include("no finished run yet",
                                         "+1 run still under way already transitioned")
        expect(response.body).not_to include("finished runs transitioned")
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

    it "describes itself with the sweep's own description" do
      experiment.update!(description: "Does a bigger neighbourhood help?")

      get experiment_path(experiment)

      expect(response.body).to include(
        %(<meta name="description" content="Does a bigger neighbourhood help?">)
      )
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
