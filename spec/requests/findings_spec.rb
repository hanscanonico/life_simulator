# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Findings", type: :request do
  let(:finding) { Findings::Registry.find("mutation-rate-window") }

  describe "GET /findings" do
    it "lists the published claims with their status" do
      get findings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(finding.title, "open")
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

    context "with the interim mutation-rate numbers" do
      it "marks the section partial and dates the lab check" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("Result (interim)", "Partial.",
                      "lab check of 2026-09-11 at 01:20 CEST, when 97 of the 100 runs had finished",
                      "a run requeued from its last snapshot drops out of the diagram until it finishes again")
      end

      it "states the interim claim with its seed counts" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("No transition in 40/40 seeds at",
                      "against 5/60 seeds at",
                      "No arm reaches more than 2 of 10, and the earliest transition anywhere in the sweep " \
                      "is epoch 9 900")
      end

      it "tabulates every arm with the runs that transitioned" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("run 41 seed 1 @ ≤ 9 900 (see caveat); run 45 seed 5 @ 13 700",
                      "run 59 seed 9 @ 19 500", "run 83 seed 3 @ 15 300", "run 95 seed 5 @ 18 080")
      end

      it "caveats the detector, the stale epoch, the unfinished arm and the control" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("Every transitioned run's final summary reports",
                      "predates the resume fix of PR #25, and its own samples put the collapse near epoch 5 030",
                      "arm, 99 and 100, were still running at the time of the check",
                      "positive control transitions")
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
