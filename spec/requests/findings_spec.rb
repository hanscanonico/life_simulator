# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Findings", type: :request do
  let(:finding) { Findings::Registry.find("mutation-rate-window") }

  describe "GET /findings" do
    it "lists the published claims with their status" do
      get findings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(finding.title, "refuted")
    end

    context "with the sweep in the lab" do
      it "links to the experiment" do
        create(:experiment, name: "Mutation rate", slug: "mutation-rate")

        get findings_path

        expect(response.body).to include(experiment_path("mutation-rate"))
      end
    end
  end

  describe "GET /findings/:slug" do
    it "renders the narrative even with no sweep in the lab" do
      get finding_path(finding)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hypothesis", "Method", "Result", "has not been")
    end

    context "with a sweep that has no finished run" do
      it "draws the diagram anyway, with a note" do
        experiment = create(:experiment, slug: "mutation-rate", epochs: 20_000,
                                         param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })
        create(:run, experiment: experiment, status: "pending")

        get finding_path(finding)

        expect(response.body).to include("Transition epoch vs mutation rate", "No run of this sweep has finished")
      end
    end

    context "with finished runs" do
      it "shows the phase diagram and every seed" do
        experiment = create(:experiment, slug: "mutation-rate", epochs: 20_000,
                                         param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })
        run = create(:run, experiment: experiment, seed: 4_242, status: "finished", transition_epoch: 900,
                           params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.0))

        get finding_path(finding)

        expect(response.body).to include("<svg", "4242", run_path(run))
      end
    end

    context "with the transitions table" do
      it "rows the flagged runs with their extrema and a CSV link" do
        experiment = create(:experiment, slug: "mutation-rate", epochs: 20_000,
                                         param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })
        run = create(:run, experiment: experiment, seed: 7, status: "finished", transition_epoch: 5_030,
                           params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))
        create(:sample, run: run, epoch: 5_030,
                        values: { "replicator_count" => 867, "entropy_bits" => 1.2, "copy_rate" => 0.31 })

        get finding_path(finding)

        expect(response.body.squish).to include("Transitions and replicator counts", "867", "1.2", "0.31")
        expect(response.body).to include(samples_run_path(run, format: :csv))
      end

      context "with nothing flagged yet" do
        it "says so" do
          create(:experiment, slug: "mutation-rate", epochs: 20_000,
                              param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })

          get finding_path(finding)

          expect(response.body.squish).to include("No finished run of this sweep has transitioned")
        end
      end
    end

    context "with the mutation-rate write-up" do
      it "states the shape of the sweep and points at the live tables" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("All 100 runs finished",
                      "which read the runs live",
                      "Nothing transitioned at any rate at or below",
                      "in no arm more often than 2 of 10")
      end

      it "says plainly that the window is not supported" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("The window is not there.",
                      "is not supported by its own data",
                      "a one-sided Fisher exact test on that 2×2 table giving",
                      "p ≈ 0.073")
      end

      it "separates the compress_ratio floor from emergence" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("climbs arm by arm from", "without a single reversal",
                      "it has nothing to do with emergence")
      end

      it "keeps the detector, the censoring and the control as caveats" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("the census disagrees with it on some flagged runs",
                      "Every 0/10 arm is censored at 20 000 epochs rather than negative",
                      "nothing here is a clean negative until the")
      end

      it "names the follow-up sweeps it hands the question to" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include(experiment_path("mutation-rate-long"), experiment_path("world-size"),
                      experiment_path("bff-control"))
      end
    end

    context "with the positive control" do
      it "states the falsifier" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response).to have_http_status(:ok)
        expect(response.body)
          .to include("suspect the interpreter or the pairing rule, not the hypothesis")
      end

      it "states the sparse cadences its runs carry" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish).to include("Sampling is sparse for a world this size",
                                                "25 full-world snapshots per run")
      end
    end

    context "with an unknown slug" do
      it "is a 404" do
        get "/findings/nope"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
