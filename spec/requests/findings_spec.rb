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

    it "points at the glossary for the words the write-ups use" do
      get findings_path

      expect(response.body.squish).to include("the glossary")
      expect(response.body).to include(how_it_works_path(anchor: "glossary"))
    end

    context "with the sweep in the lab" do
      it "links to the experiment" do
        create(:experiment, name: "Mutation rate", slug: "mutation-rate")

        get findings_path

        expect(response.body).to include(experiment_path("mutation-rate"))
      end

      it "states how far the sweep has got on the row" do
        experiment = create(:experiment, name: "Mutation rate", slug: "mutation-rate")
        create(:run, experiment: experiment, status: "finished", transition_epoch: 5_030)
        create(:run, experiment: experiment, status: "finished", transition_epoch: nil)
        create(:run, experiment: experiment, status: "pending")

        get findings_path

        expect(response.body.squish).to include("2 / 3 runs finished · 1 transitioned (50%)")
      end
    end

    context "with the sweep missing" do
      it "says so instead of stating progress" do
        get findings_path

        expect(response.body.squish).to include("is not in the lab yet")
        expect(response.body.squish).not_to match(%r{\d+ / \d+ runs finished})
      end
    end
  end

  describe "GET /findings/:slug" do
    it "renders the narrative even with no sweep in the lab" do
      get finding_path(finding)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hypothesis", "Method", "Result", "has not been")
    end

    it "points its evidence at the glossary" do
      get finding_path(finding)

      expect(response.body.squish).to include("used here in the senses set out in")
      expect(response.body).to include(how_it_works_path(anchor: "glossary"))
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

      it "explains what each table rows and what a dash means" do
        experiment = create(:experiment, slug: "mutation-rate", epochs: 20_000,
                                         param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })
        create(:run, experiment: experiment, seed: 7, status: "finished", transition_epoch: 5_030,
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))

        get finding_path(finding)

        expect(response.body.squish)
          .to include("One row per finished run the detector flagged or that counted at least one replicator",
                      %("—" means the run never had a value),
                      "Every run of the sweep, flagged or not, with its seed — the denominator of the rate above")
      end

      context "with nothing flagged yet" do
        it "says so, and still explains the table" do
          create(:experiment, slug: "mutation-rate", epochs: 20_000,
                              param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })

          get finding_path(finding)

          expect(response.body.squish)
            .to include("No finished run of this sweep has transitioned",
                        "One row per finished run the detector flagged",
                        "the denominator of the rate above")
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
        rates = Lab::SWEEPS.fetch("mutation_rate").fetch(:param_grid).fetch("mutation_rate")
        ceiling = -Math.log2(rates.max).round

        get finding_path(finding)

        expect(response.body.squish)
          .to include("<h2>What next</h2>", "2<sup>-#{ceiling}</sup>", "mutation_rate = 0",
                      "nothing to do with emergence")
      end

      it "says the census agrees where the effect is strong" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("The census agrees where the effect is strong.",
                      "the first and the fifth seed of the",
                      "The lineage is in the world, not in the sampling.")
      end

      it "explains why a terminal snapshot under-counts the census" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("The census fades; the compression does not.",
                      "reads the world after the lineage is gone and reports none",
                      "a snapshot-retention artefact")
      end

      it "reports the three single-observable disagreements as disagreements" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("Three runs still disagree with themselves.",
                      "the ninth seed of the", "the fifth seed of the",
                      "the second seed of the",
                      "Ranking width is not the explanation",
                      "the cut stays where DESIGN §1.2 locks it, at 16")
      end

      it "keeps the detector, the censoring and the control as caveats" do
        get finding_path(finding)

        expect(response.body.squish)
          .to include("the census disagrees with it on some flagged runs",
                      "Every 0/10 arm is censored at 20 000 epochs rather than negative",
                      "nothing here is a clean negative until the")
      end

      it "draws the earliest transitioning run inline once that run is in the lab" do
        experiment = create(:experiment, name: "Mutation rate", slug: "mutation-rate", epochs: 20_000)
        run = create(:run, experiment: experiment, seed: 1, status: "finished", transition_epoch: 5_030,
                           params: Lab::Schema.run_defaults.merge("mutation_rate" => Lab::EMERGENT_MUTATION_RATE))
        create(:sample, run: run, epoch: 5_000, values: { "compress_ratio" => 0.98 })
        create(:sample, run: run, epoch: 5_030, values: { "compress_ratio" => 0.41 })

        get finding_path(finding)

        expect(response.body.squish).to include("The earliest transition of the sweep",
                                                "Compression ratio", "seed 1")
        expect(response.body).to include(%(class="chart-cited"), run_path(run))
      end

      context "with none of its runs in this database" do
        it "prints the narrative without the inline chart" do
          get finding_path(finding)

          expect(response.body).to include("The earliest transition of the sweep")
          expect(response.body).not_to include("chart-cited")
        end
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
        control = Findings::Registry.find("bff-control")

        get finding_path(control)

        expect(response).to have_http_status(:ok)
        expect(response.body)
          .to include(%(<span class="badge #{control.badge_class}">#{control.status_label}</span>))
        expect(response.body.squish[%r{<h2>Hypothesis</h2>(.*?)<h2>}, 1]).to include("falsifier")
      end

      it "states the sparse cadences its runs carry" do
        sweep = Lab::SWEEPS.fetch("bff_control")
        sample_every = sweep.fetch(:param_grid).fetch("sample_every").sole
        snapshot_every = sweep.fetch(:param_grid).fetch("snapshot_every").sole

        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("sample_every = #{sample_every}", "snapshot_every = #{snapshot_every}",
                      "#{sweep.fetch(:epochs) / snapshot_every} full-world snapshots per run")
      end

      it "states the transition as a shape and points at the live evidence table" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("in one of its three seeds",
                      "the evidence table below, which reads the runs live",
                      "controls sit at the random-soup baseline")
      end

      it "reads its census peak as not yet resolved rather than as no evidence" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("And the census is not zero.",
                      "in the lab — thousands of replicating cells at its peak",
                      "no snapshot falls inside the window where the count was high",
                      "Truncation of the ranking is ruled out",
                      "not yet resolved rather than not evidence",
                      "neither triggered nor retired")
      end

      it "reads the zero-mutation control as the negative result it is" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("What the zero-mutation control shows",
                      "a copying cascade of the tapes the seed handed the world",
                      "an entropy collapse on its own is not evidence of a replicator",
                      "the snapshot forced on the sample where a transition settles")
      end

      it "keeps the requeue history" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish).to include("10 MiB cap on an API response",
                                                "requeued from their last snapshot")
      end

      it "leaves lab timestamps and per-run facts out of the body" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body).not_to match(/\d{2}:\d{2} CEST/)
        expect(response.body).not_to match(/\brun \d+/i)
        expect(response.body).not_to match(/epoch \d ?\d{3}/)
      end
    end

    context "with the world-size stub" do
      it "states the two rival readings the sweep separates" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response).to have_http_status(:ok)
        expect(response.body.squish).to include("lottery", "per-cell rate")
      end

      it "states the shape both observables agree on" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("Replicators appear only in the largest world.",
                      "no seed of the two smallest worlds moved on either observable",
                      "three seeds moved on both",
                      "its fraction can only rise")
      end

      it "keeps the collapse without a census apart from a replicator" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("Below it, a collapse that is not a replicator.",
                      "with a census of zero at every sample",
                      "not a replicator by the test DESIGN §1.2 locks")
      end

      it "names the tension with the mutation-rate sweep" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("The two sweeps do not agree yet.",
                      "at half this sweep's mutation rate",
                      "The two differ in nothing else.")
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

    context "with the radius stub" do
      it "states the shape so far and holds off on a claim" do
        get finding_path(Findings::Registry.find("radius-locality"))

        expect(response).to have_http_status(:ok)
        expect(response.body.squish)
          .to include("no claim is made here yet",
                      "connectivity buys emergence",
                      "the two tightest arms produce none")
      end

      it "reads its arms from the sweep the lab would build" do
        sweep = Lab::SWEEPS.fetch("radius")
        redefined = sweep.merge(param_grid: sweep.fetch(:param_grid).merge("radius" => [3, 0]), epochs: 512)
        stub_const("Lab::SWEEPS", Lab::SWEEPS.merge("radius" => redefined))

        get finding_path(Findings::Registry.find("radius-locality"))

        expect(response.body.squish).to include("3 and 0", "512 epochs per run")
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
