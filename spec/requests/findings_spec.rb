# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Findings", type: :request do
  let(:finding) { Findings::Registry.find("mutation-rate-window") }

  describe "GET /findings" do
    it "lists the published claims with their status" do
      get findings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(finding.title, "partial")
    end

    it "legends what each status means" do
      get findings_path

      expect(response.body.squish).to include(*Findings::Finding::STATUS_MEANINGS.values)
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

    context "with the final mutation-rate numbers" do
      it "reports the sweep as finished and the emergence that happened" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("All 100 runs finished. Five transitioned",
                      "the first at epoch 5 030",
                      "The other 95 were censored at 20 000 epochs")
      end

      it "says plainly that the window is not supported" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("The window is not there.",
                      "is not supported by its own data",
                      "A one-sided Fisher exact test on that 2×2 table gives",
                      "p ≈ 0.073")
      end

      it "tabulates every arm with the runs that transitioned" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("5 030 (<a href=\"#{run_path(41)}\">run 41</a>, seed 1)",
                      "7 000 (<a href=\"#{run_path(45)}\">run 45</a>, seed 5)",
                      "15 560 (<a href=\"#{run_path(59)}\">run 59</a>, seed 9)",
                      "10 670 (<a href=\"#{run_path(83)}\">run 83</a>, seed 3)",
                      "18 080 (<a href=\"#{run_path(95)}\">run 95</a>, seed 5)")
      end

      it "separates the compress_ratio floor from emergence" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("climbs arm by arm from ≈ 0.92 at",
                      "to ≈ 0.99 at",
                      "without a single reversal",
                      "those three arms sit between 0.91 and 0.93, with the no-mutation arm the highest",
                      "it has nothing to do with emergence")
      end

      it "keeps the detector and the control as caveats" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("detector fires in only three of the five transitioned runs",
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

    context "with the world-size stub" do
      it "states the two rival readings and holds off on a claim" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response).to have_http_status(:ok)
        expect(response.body.squish).to include("lottery", "per-cell rate", "no claim is made yet")
      end

      it "reads its grid from the sweep the lab would build" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish).to include("32×32, 64×64, 128×128 and 256×256")
      end

      context "with the programme's world-size sweep redefined" do
        it "follows the sweep instead of restating its arms and budget" do
          sweep = Lab::SWEEPS.fetch("world_size")
          redefined = sweep.merge(param_grid: { "world_size" => [{ "width" => 8, "height" => 8 }] }, epochs: 512)
          stub_const("Lab::SWEEPS", Lab::SWEEPS.merge("world_size" => redefined))

          get finding_path(Findings::Registry.find("world-size-scaling"))

          expect(response.body.squish).to include("8×8", "512-epoch budget is short")
          expect(response.body.squish).not_to include("32×32")
        end
      end

      it "names the control and the budget as the reasons a flat sweep is unreadable" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish).to include(finding_path("bff-control"), "20 000-epoch budget is short")
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
