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
      it "marks the section partial and held on the positive control" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("Result (interim)", "Partial, and not yet a result.",
                      "held until the high arms and run 45 finish",
                      "positive control has not transitioned yet")
      end

      it "reports the one run that transitioned, with its numbers" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("1 of 9 finished runs — run 41, seed 1.",
                      "sits at 0.94 until about epoch 5000, then falls 0.725 → 0.526 → 0.052 " \
                      "within 100 epochs and ends at 0.26 at 20 000 epochs",
                      "drops from 7.9 to 6.2 across the same window",
                      "is 538 at epoch 5000 and peaks at 867, then is back to 0 after epoch 5500")
      end

      it "counts the arms that have finished and the run still going" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("the count is 0 of 10 transitions in each arm, seeds 1 to 10",
                      "median 0.91 to 0.93 at 20 000 epochs", "0 of 4 finished runs have transitioned at",
                      "Run 45 (seed 5, same arm) is still running with a peak")
      end

      it "flags the transition epoch its samples disagree with" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("recorded for run 41 is 9900, while its own samples first fall below 0.6 at epoch 5030")
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
