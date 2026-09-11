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

    it "strips the programme's standing under the heading" do
      create(:run, status: "finished", epochs_done: 90, transition_epoch: 12)

      get findings_path

      expect(response.parsed_body.css(".facts").first.css("dd").map(&:text)).to eq(%w[1 1 90 1 —])
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
        it "prints the narrative without promising a chart it cannot draw" do
          get finding_path(finding)

          expect(response.body).not_to include("The earliest transition of the sweep")
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
        expect(response.body.squish).to include("lottery", "per cell-epoch", "per <em>run</em>-epoch")
      end

      it "states the per-arm counts in a table that links the runs by arm and seed" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("Emergence gets more likely as the world gets bigger.",
                      "the counts run 0, 0, 1 and 3 of 10",
                      "0 of 10", "1 of 10", "3 of 10",
                      "15 560", "4 730", "15 800", "19 550")
      end

      it "states the test of the per-cell hazard and what four events cannot measure" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("The per-cell reading is the one that fits, and here is the test.",
                      "the arms should show about 0.06, 0.26, 1 and 3.7 events",
                      "about one time in eight",
                      "2.5 × 10<sup>-10</sup></span> per cell-epoch",
                      "Four events cannot measure an exponent.")
      end

      it "names the earliest transition of the programme without over-reading it" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("The earliest transition of the whole programme is in the largest world.",
                      "crossed at epoch 4 730",
                      "not evidence that a bigger world runs faster per run")
      end

      it "keeps the collapse without a census apart from a replicator" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("Below the largest arm, a collapse that is not a replicator.",
                      "with a census of zero at every sample",
                      "not a replicator by the test DESIGN §1.2 locks")
      end

      it "reports the pre-emergence soup as unchanged by size" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("Size does not change the pre-emergence soup.",
                      "between 0.93 and 0.96 in every arm",
                      "the same soup")
      end

      it "reports the determinism cross-check the default arm gives for free" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include("A determinism cross-check, for free.",
                      "the ninth seed at epoch 15 560",
                      "30 runs of new evidence and 10 of a repeat")
      end

      it "hands the scaling question to the positive control and the survival section" do
        get finding_path(Findings::Registry.find("world-size-scaling"))

        expect(response.body.squish)
          .to include(experiment_path("bff-control"), experiment_path("world-size"),
                      "the survival and hazard section", "It is not a fifth arm of this sweep")
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

    context "with the radius write-up" do
      let(:radius) { Findings::Registry.find("radius-locality") }

      it "states the negative on the speed half of the hypothesis" do
        get finding_path(radius)

        expect(response).to have_http_status(:ok)
        expect(response.body.squish)
          .to include("Locality did not speed emergence.",
                      "transitioned as often as the best local arm",
                      "is not in the data")
      end

      it "states what ten seeds per arm can resolve" do
        get finding_path(radius)

        expect(response.body.squish)
          .to include("2 of 10 against 1 of 10", "p = 0.5",
                      "until it shows 4 transitions where the other shows none",
                      "a factor of two hiding in here would be invisible")
      end

      # The hazard table is rendered by the experiment page, not by this one, so the
      # narrative has to send the reader there rather than say "below".
      it "sends the reader to the sweep's page for the hazard intervals and sizes them" do
        get finding_path(radius)

        expect(response.body.squish)
          .to include("The hazard section on the sweep's page",
                      "30-fold wide in the arms with two events and more than 200-fold wide")
        expect(response.body.squish).not_to include("hazard section below", "hazard table and the per-run rows below")
      end

      it "keeps the compress_ratio trend as an observation about the soup" do
        get finding_path(radius)

        expect(response.body.squish)
          .to include("0.951, 0.901, 0.860", "the well-mixed arm sits at 0.859",
                      "about the soup, not about emergence")
      end

      it "reports the transition that did not hold" do
        get finding_path(radius)

        expect(response.body.squish)
          .to include("One transition did not hold.", "climbs back through the 0.6 line",
                      "a state a world can leave again")
      end

      it "states the determinism cross-check and the repeated arm" do
        get finding_path(radius)

        expect(response.body.squish)
          .to include("All ten seeds reproduce", "digit for digit",
                      "agrees wherever all three recorded it",
                      "that arm is not an independent sample")
        expect(response.body).to include(finding_path("mutation-rate-window"), finding_path("world-size-scaling"))
      end

      it "leaves the diversity half of the hypothesis open and names the lens for the rest" do
        get finding_path(radius)

        expect(response.body.squish)
          .to include("<h2>What next</h2>", "stays open",
                      "The hazard section on the")
        expect(response.body).to include(experiment_path("radius"))
      end

      it "names each transitioned run by its arm and seed, without a database id" do
        get finding_path(radius)

        expect(response.body.squish).to include("15 560 (seed 9)", "5 910 (seed 10)")
      end

      context "with the cited run in the lab" do
        it "links the row to it" do
          experiment = create(:experiment, name: "Neighbourhood radius", slug: "radius", epochs: 20_000)
          run = create(:run, experiment: experiment, seed: 9, status: "finished", transition_epoch: 15_560,
                             params: Lab::Schema.run_defaults.merge("radius" => 1))

          get finding_path(radius)

          expect(response.body).to include(%(<a href="#{run_path(run)}">seed 9</a>))
        end
      end

      it "reads its arms from the sweep the lab would build" do
        sweep = Lab::SWEEPS.fetch("radius")
        redefined = sweep.merge(param_grid: sweep.fetch(:param_grid).merge("radius" => [3, 0]), epochs: 512)
        stub_const("Lab::SWEEPS", Lab::SWEEPS.merge("radius" => redefined))

        get finding_path(radius)

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
