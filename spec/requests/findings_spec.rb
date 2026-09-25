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

    context "with a finding that names no sweep" do
      let(:table_link) do
        anchor = finding_path("emergence-can-be-left", anchor: "transitioned-runs")

        %(<a href="#{anchor}">2 terminal runs that crossed, finished or failed</a>)
      end

      it "rows it against every transitioned run instead of a missing sweep" do
        crossed = create(:run, status: "finished", transition_epoch: 900)
        died = create(:run, status: "failed", transition_epoch: 900)
        still_going = create(:run, status: "running", transition_epoch: 900)

        get findings_path

        expect(response.body.squish)
          .to include("Emergence is a state a world can leave",
                      %(<a href="#{experiment_path(crossed.experiment)}">#{crossed.experiment.name}</a>),
                      %(<a href="#{experiment_path(died.experiment)}">#{died.experiment.name}</a>),
                      table_link)
        expect(response.body).not_to include(experiment_path(still_going.experiment))
      end
    end

    context "with a finding weighing several sweeps" do
      it "links each of them on the row" do
        sweeps = %w[energy_per_epoch environmental_structure max_tape_len].map do |key|
          create(:experiment, name: Lab::SWEEPS.fetch(key).fetch(:name), slug: Lab.slug_for(key))
        end

        get findings_path

        expect(response.body.squish).to include("Weighed against each other, and against the substrate they vary")
        sweeps.each { |sweep| expect(response.body).to include(experiment_path(sweep)) }
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

    context "with the long-horizon re-run" do
      let(:long_run) { Findings::Registry.find("mutation-rate-long-horizon") }

      it "states what the longer budget added to the short sweep" do
        get finding_path(long_run)

        expect(response).to have_http_status(:ok)
        expect(response.body.squish)
          .to include("The short sweep was right, and it under-counted.",
                      "three transitions; the 60 000-epoch budget finds eight",
                      "three of them fall after epoch 20 000")
        expect(response.body).to include(finding_path("mutation-rate-window"))
      end

      it "counts the same flagged runs in its prose as in its per-arm table" do
        get finding_path(long_run)

        flagged = response.parsed_body.css("table.data-table").first.css("tbody tr")
                          .sum { |row| row.css("td")[1].text.squish.to_i }

        expect(flagged).to eq(8)
        expect(response.body.squish).to include("budget finds eight", "this sweep has 8 events")
      end

      it "reports the disagreement the longer clock resolved" do
        get finding_path(long_run)

        expect(response.body.squish)
          .to include("A disagreement that was only the clock.", "counts its first replicating cell at epoch 26 140",
                      "was the budget and not the substrate")
      end

      it "holds the lower cutoff open rather than calling the arm a zero" do
        get finding_path(long_run)

        expect(response.body.squish)
          .to include("The lower cutoff survives three times the budget.",
                      "they do not abolish it")
      end

      it "reports the transition that dissolved and the two empty censuses" do
        get finding_path(long_run)

        expect(response.body.squish)
          .to include("Two runs flagged with an empty census", "of 0.952 with all 16 384 tapes distinct",
                      "read on the census it has 6")
      end

      it "reads its arms, its seeds and its budget from the sweep the lab would build" do
        sweep = Lab::SWEEPS.fetch("mutation_rate_long")
        redefined = sweep.merge(param_grid: sweep.fetch(:param_grid).merge("mutation_rate" => [2.0**-13]),
                                epochs: 512)
        stub_const("Lab::SWEEPS", Lab::SWEEPS.merge("mutation_rate_long" => redefined))

        get finding_path(long_run)

        expect(response.body.squish).to include("512 epochs per run", "0 of the 10 runs have reached 512 epochs")
      end

      context "with runs of the sweep in this database" do
        it "counts the terminal ones at render time and draws the cited census" do
          experiment = create(:experiment, name: "Mutation rate, long runs", slug: "mutation-rate-long",
                                           epochs: 60_000)
          run = create(:run, experiment: experiment, seed: 9, status: "finished", transition_epoch: 15_560,
                             params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-12))
          create(:run, experiment: experiment, seed: 8, status: "running")
          create(:sample, run: run, epoch: 26_140, values: { "replicator_count" => 57 })

          get finding_path(long_run)

          expect(response.body.squish).to include("1 of the 40 runs have reached 60 000 epochs")
          expect(response.body).to include(%(class="chart-cited"), run_path(run))
        end
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

      it "reads its census as confirmed by rescore off the peak and open at the peak" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("And the census is not zero.",
                      "in the lab — thousands of replicating cells at its peak",
                      "316 replicating cells at epoch 9 900, 112 at epoch 16 000",
                      "What no stored world holds is the peak itself",
                      "confirmed off the peak and unresolved at it",
                      "neither triggered nor retired")
      end

      it "reads the census wider than the locked cut without moving the cut" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("Truncation of the ranking is not ruled out here",
                      "zero at the top 16 tapes and 38 at both 64 and 256",
                      "only two are zero at 16 and positive at 64",
                      "top_k</span> stays where DESIGN §1.2 locks it, at 16")
        expect(response.body).not_to include("identical metrics")
      end

      it "reads the zero-mutation control as the negative result it is" do
        get finding_path(Findings::Registry.find("bff-control"))

        expect(response.body.squish)
          .to include("What the zero-mutation control shows",
                      "a copying cascade of the tapes the seed handed the world",
                      "an entropy collapse on its own is not evidence of a replicator",
                      "writes a snapshot whenever the census rises off zero")
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
        expect(response.body).not_to match(/\bseed \d+/i)
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
                      "with every run censored where it was last watched",
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

    context "with the interaction budget" do
      let(:budget) { Findings::Registry.find("interaction-budget") }

      it "states the non-monotone shape against the floor the sweep expected" do
        get finding_path(budget)

        expect(response).to have_http_status(:ok)
        expect(response.body.squish)
          .to include("More compute per interaction is not more life.",
                      "what the sweep shows is 0, 0, 2 and 0",
                      "an optimum rather than a threshold")
      end

      it "counts the same flagged runs in its prose as in its per-arm table" do
        get finding_path(budget)

        flagged = response.parsed_body.css("table.data-table").first.css("tbody tr")
                          .sum { |row| row.css("td")[1].text.squish.to_i }

        expect(flagged).to eq(2)
        expect(response.body.squish).to include("in 2 of 10 seeds")
      end

      it "reports that the detector and the census name the same two runs" do
        get finding_path(budget)

        disagreements = response.parsed_body.css("table.data-table").first.css("tbody tr")
                                .sum { |row| row.css("td").last.text.squish.to_i }

        expect(disagreements).to eq(0)
        expect(response.body.squish).to include("The detector and the census agree everywhere.")
        expect(response.body).to include(finding_path("mutation-rate-long-horizon"))
      end

      it "bounds the silent arms instead of reading them as zeros" do
        get finding_path(budget)

        expect(response.body.squish)
          .to include("bounds a per-arm rate to roughly 0 to 26%",
                      "Clopper–Pearson upper bound is 0.259",
                      "p = 0.24",
                      "a peak located to within a factor of 64")
      end

      it "states the determinism cross-check and the arm it repeats" do
        get finding_path(budget)

        expect(response.body.squish)
          .to include("A determinism cross-check, and a caveat with it.",
                      "30 runs of new evidence and 10 of a repeat")
        expect(response.body).to include(finding_path("mutation-rate-window"))
      end

      it "prices an epoch of every arm and makes the prose quote its own table" do
        get finding_path(budget)

        rows = response.parsed_body.css("table.data-table").last.css("tbody tr")
        rates = rows.map { |row| row.css("td")[1].text.squish.to_f }

        expect(rates).to eq([74.4, 62.6, 29.5, 6.0])
        expect(rates).to eq(rates.sort.reverse)
        expect(response.body.squish)
          .to include("about #{(rates.first / rates.last).round} times what an epoch at 256 costs",
                      "3.3, 2.5 and 2.3 microseconds per epoch",
                      "the marginal price would thin with it. Over three octaves it barely does.")
      end

      it "reads the slower transition as ending in the more uniform world" do
        get finding_path(budget)

        prose = response.parsed_body.text.squish
        collapsed = prose[/compress_ratio ([\d.]+) against ([\d.]+)/, 1].to_f
        against = prose[/compress_ratio ([\d.]+) against ([\d.]+)/, 2].to_f

        expect(collapsed).to be < against
        expect(prose).to include("ends the run further gone than the first",
                                 "2 406 distinct tapes against 13 349",
                                 "end in the more uniform world, not the less uniform one")
      end

      it "counts the copy-rate blips per arm and reads them as rising with the budget" do
        get finding_path(budget)

        blips = response.parsed_body.css("table.data-table").last.css("tbody tr")
                        .map { |row| row.css("td").last.text.squish.to_i }

        expect(blips).to eq([1, 2, 4, 5])
        expect(response.body.squish)
          .to include("#{blips.sum} of those 38 runs do show a",
                      "4 of the 8 silent runs at 8 192",
                      "not noise spread evenly over the arms")
      end

      it "reads the transitioned runs as the slow ones rather than as contention" do
        get finding_path(budget)

        expect(response.body.squish)
          .to include("31.0 epochs per second before epoch 5 030 and 14.7 after it",
                      "9.2 and 8.6 against 12.5 and 11.0")
      end

      it "names the finer grid as a proposal rather than a promise" do
        get finding_path(budget)

        expect(response.body.squish)
          .to include("<h2>What next</h2>", "2 048, 4 096, 8 192, 16 384 and 32 768 at 20 seeds each",
                      "a proposal and not a commitment")
      end

      it "names each transitioned run by its arm and seed, without a database id" do
        get finding_path(budget)

        expect(response.body.squish).to include("5 030 (seed 1, 867)", "7 000 (seed 5, 108)")
        expect(response.body).not_to match(/\brun #?\d+/i)
      end

      it "reads its arms, its seeds and its budget from the sweep the lab would build" do
        sweep = Lab::SWEEPS.fetch("max_steps")
        redefined = sweep.merge(param_grid: sweep.fetch(:param_grid).merge("max_steps" => [2**13]), epochs: 512)
        stub_const("Lab::SWEEPS", Lab::SWEEPS.merge("max_steps" => redefined))

        get finding_path(budget)

        expect(response.body.squish).to include("512 epochs per run", "0 of the 10 runs have reached 512 epochs")
      end

      context "with runs of the sweep in this database" do
        it "counts the terminal ones at render time and draws the cited census" do
          experiment = create(:experiment, name: "Max steps per interaction", slug: "max-steps", epochs: 20_000)
          run = create(:run, experiment: experiment, seed: 1, status: "finished", transition_epoch: 5_030,
                             params: Lab::Schema.run_defaults.merge("max_steps" => 8_192))
          create(:run, experiment: experiment, seed: 5, status: "running")
          create(:sample, run: run, epoch: 5_080, values: { "replicator_count" => 867 })

          get finding_path(budget)

          expect(response.body.squish).to include("1 of the 40 runs have reached 20 000 epochs")
            .and include("recorded once every one of the 40 had finished")
          expect(response.body).to include(%(class="chart-cited"), run_path(run))
        end
      end
    end

    context "with the persistence write-up" do
      let(:persistence) { Findings::Registry.find("emergence-can-be-left") }

      def transitioned_run(experiment, seed, persistence_summary, samples_after: 4)
        run = create(:run, experiment: experiment, seed: seed, status: "finished", transition_epoch: 1_000,
                           persistence: persistence_summary)
        samples_after.times { |index| create(:sample, run: run, epoch: 1_000 + (index * 10)) }
        run
      end

      it "states the rule it reads a stored series by, and what it does not claim" do
        get finding_path(persistence)

        expect(response.body.squish)
          .to include("Emergence is a state a world can leave",
                      "the state ends at the first of 4 consecutive samples the rule rejects",
                      "A persister persisted to its last sample, not forever.",
                      "No hazard is estimated.",
                      "Entering and leaving are decided by compression alone.",
                      "not a colony that died",
                      "The exit rule is a Rails-side definition.")
      end

      it "says its evidence is every transitioned run rather than one sweep" do
        get finding_path(persistence)

        expect(response.body.squish).to include("This finding rests on no single sweep")
        expect(response.body.squish).not_to include("has not been queued in the lab yet")
      end

      it "says nothing of what became of runs it has no summary for" do
        create(:run, status: "finished", transition_epoch: 900)

        get finding_path(persistence)

        expect(response.body.squish)
          .to include("No transitioned world in the lab has been read for what became of it yet",
                      "a persistence summary behind 0 of them")
        expect(response.body.squish).not_to include("has left the state yet.")
      end

      it "says plainly that nothing has transitioned yet" do
        get finding_path(persistence)

        expect(response.body.squish).to include("No terminal run in this database has a transition epoch yet")
      end

      context "with as many worlds having left the state as held it" do
        it "claims neither side of the split" do
          sweep = create(:experiment)
          transitioned_run(sweep, 1, { "census_peak" => 7, "peak_epoch" => 1_020,
                                       "epochs_persisted" => 400, "relapsed" => false })
          transitioned_run(sweep, 2, { "census_peak" => 7, "peak_epoch" => 1_020,
                                       "epochs_persisted" => 80, "relapsed" => true })

          get finding_path(persistence)

          expect(response.body.squish)
            .to include("as many worlds have left it as have held it")
          expect(response.body.squish).not_to include("more worlds leave it than hold it")
        end
      end

      context "with more worlds having left the state than held it" do
        it "says so" do
          sweep = create(:experiment)
          transitioned_run(sweep, 1, { "census_peak" => 7, "peak_epoch" => 1_020,
                                       "epochs_persisted" => 400, "relapsed" => true })
          transitioned_run(sweep, 2, { "census_peak" => 7, "peak_epoch" => 1_020,
                                       "epochs_persisted" => 80, "relapsed" => true })

          get finding_path(persistence)

          expect(response.body.squish).to include("more worlds leave it than hold it")
        end
      end

      context "with transitioned runs in the database" do
        it "counts the persisters and the relapsers and links the sweeps and the runs" do
          radius = create(:experiment, name: "Radius", slug: "radius")
          held = transitioned_run(radius, 1, { "census_peak" => 7, "peak_epoch" => 1_020,
                                               "epochs_persisted" => 400, "relapsed" => false })
          left = transitioned_run(radius, 2, { "census_peak" => 123, "peak_epoch" => 1_040,
                                               "epochs_persisted" => 80, "relapsed" => true })

          get finding_path(persistence)

          expect(response.body.squish)
            .to include("The lab has 2 terminal runs that crossed, finished or failed, across 1 sweep, " \
                        "and a persistence summary behind 2 of them",
                        "The split is 1 still in the transitioned state at their last sample against 1 " \
                        "that climbed back out of it",
                        "50% of the summarised runs relapsed",
                        "held the state for 80 to 400 epochs, a median of 80",
                        "peak at 7 to 123 cells, a median of 7")
          expect(response.body).to include(experiment_path(radius), run_path(held), run_path(left),
                                           "relapsed", "persisted")
        end

        it "splits the outcome by whether the census ever saw a colony" do
          sweep = create(:experiment)
          transitioned_run(sweep, 1, { "census_peak" => 123, "peak_epoch" => 1_040,
                                       "epochs_persisted" => 80, "relapsed" => true })
          transitioned_run(sweep, 2, { "census_peak" => 7, "peak_epoch" => 1_020,
                                       "epochs_persisted" => 400, "relapsed" => false })
          transitioned_run(sweep, 3, { "census_peak" => 0, "peak_epoch" => nil,
                                       "epochs_persisted" => 60, "relapsed" => true })

          get finding_path(persistence)

          expect(response.body.squish)
            .to include("Of the 2 summarised runs that counted a replicating cell, 1 persisted and 1 relapsed",
                        "Of the 1 run whose census never left zero — or was never taken — 0 persisted " \
                        "and 1 relapsed",
                        "worlds the census never saw as a colony at all")
        end

        it "rows every transitioned run and says so" do
          transitioned_run(create(:experiment), 1, { "census_peak" => 7, "peak_epoch" => 1_020,
                                                     "epochs_persisted" => 400, "relapsed" => false })

          get finding_path(persistence)

          expect(response.body.squish).to include("Every transitioned run in the lab has a row")
        end

        it "names what a capped table leaves out, and says the figures still count it" do
          stub_const("Findings::ShowPage::MAX_TRANSITIONS", 1)
          sweep = create(:experiment)
          2.times do |index|
            transitioned_run(sweep, index, { "census_peak" => 7, "peak_epoch" => 1_020,
                                             "epochs_persisted" => 400, "relapsed" => false })
          end

          get finding_path(persistence)

          expect(response.body.squish)
            .to include("The table stops at 1 row and leaves 1 further transitioned run out; every one " \
                        "of them is counted in the figures above")
          expect(response.parsed_body.css("#transitioned-runs tbody tr").size).to eq(1)
        end

        it "flags the persisters with no room for an exit to be confirmed in" do
          transitioned_run(create(:experiment), 1,
                           { "census_peak" => 7, "peak_epoch" => 1_020,
                             "epochs_persisted" => 10, "relapsed" => false }, samples_after: 2)

          get finding_path(persistence)

          expect(response.body.squish)
            .to include("Fewer than 4 samples stand at or after the crossing in 1 persister")
        end
      end
    end

    context "with the copy-cost write-up" do
      let(:copy_cost) { Findings::Registry.find("copy-cost-adaptation") }

      def run_with_costs(experiment, seed, costs)
        run = create(:run, experiment: experiment, seed: seed, status: "finished", transition_epoch: 1_000)
        costs.each_with_index do |cost, index|
          create(:sample, run: run, epoch: 1_000 + (index * 10), values: { "copy_cost" => cost })
        end
        run
      end

      it "states what copy cost is and what the count does not claim" do
        get finding_path(copy_cost)

        expect(response.body.squish)
          .to include("Does copying get cheaper?",
                      "copies itself in 1 794 steps",
                      "This is not the adaptation sweep.",
                      %("Dominant replicator" is a tape, not a lineage.),
                      "Every series is censored at both ends.",
                      "Steps are not fitness.")
      end

      it "says plainly that no run has recorded a cost yet" do
        create(:run, status: "finished", transition_epoch: 900)

        get finding_path(copy_cost)

        expect(response.body.squish).to include("No run in this database has recorded a copy cost yet")
      end

      context "with recorded costs in the database" do
        it "counts the directions and links the sweeps and the runs" do
          radius = create(:experiment, name: "Radius", slug: "radius")
          cheaper = run_with_costs(radius, 1, [1_794, 1_600, 1_200])
          dearer = run_with_costs(radius, 2, [900, 1_500])

          get finding_path(copy_cost)

          expect(response.body.squish)
            .to include("The lab has 2 terminal runs that crossed, with a copy cost recorded after " \
                        "the crossing in 2 of them, across 1 sweep",
                        "Among the 2 runs with at least two readings, the split is 1 ending below " \
                        "their first post-transition cost, 1 above it and 0 on it")
          expect(response.body).to include(experiment_path(radius), run_path(cheaper), run_path(dearer),
                                           "cheaper", "dearer")
        end

        it "names what a capped table leaves out, and says the figures still count it" do
          stub_const("Findings::ShowPage::MAX_TRANSITIONS", 1)
          sweep = create(:experiment)
          2.times { |index| run_with_costs(sweep, index, [1_794, 1_200]) }

          get finding_path(copy_cost)

          expect(response.body.squish)
            .to include("The table stops at 1 row and leaves 1 further run out")
          expect(response.parsed_body.css("#copy-cost-runs tbody tr").size).to eq(1)
        end
      end
    end

    context "with the complexity write-up" do
      let(:complexity) { Findings::Registry.find("replicator-complexity-plateau") }

      def run_with_lengths(experiment, seed, lengths)
        run = create(:run, :emerged, experiment: experiment, seed: seed, transition_epoch: 1_000)
        lengths.each_with_index do |length, index|
          create(:sample, run: run, epoch: 1_000 + (index * 10),
                          values: { "dominant_compressed_len" => length, "dominant_instruction_count" => 15 })
        end
        run
      end

      it "states what the two readings are and what the count does not claim" do
        get finding_path(complexity)

        expect(response.body.squish)
          .to include("Does the replicator keep getting more complicated?",
                      "36 bytes and 15 instructions",
                      "Compressed length is size, not ability.",
                      %("Dominant replicator" is a tape, not a lineage.),
                      "A plateau here is a plateau at these budgets.",
                      "This is not the open-endedness sweep.")
      end

      it "says plainly that no run has recorded a complexity yet" do
        create(:run, status: "finished", transition_epoch: 900)

        get finding_path(complexity)

        expect(response.body.squish)
          .to include("No run in this database has recorded the complexity of its dominant replicator yet")
      end

      context "with recorded complexities in the database" do
        it "counts the directions and links the sweeps and the runs" do
          radius = create(:experiment, name: "Radius", slug: "radius")
          grown = run_with_lengths(radius, 1, [36, 40, 52])
          shrunk = run_with_lengths(radius, 2, [80, 44])

          get finding_path(complexity)

          expect(response.body.squish)
            .to include("The lab has 2 terminal runs flagged by the detector and 2 confirmed by a " \
                        "replicator, with a complexity reading after the crossing in 2 of the confirmed " \
                        "ones, across 1 sweep",
                        "Among the 2 runs with at least two readings, the split is 1 ending above " \
                        "their first post-emergence length, 1 below it and 0 on it")
          expect(response.body).to include(experiment_path(radius), run_path(grown), run_path(shrunk),
                                           "more complicated", "simpler")
        end

        it "names what a capped table leaves out, and says the figures still count it" do
          stub_const("Findings::ShowPage::MAX_TRANSITIONS", 1)
          sweep = create(:experiment)
          2.times { |index| run_with_lengths(sweep, index, [36, 52]) }

          get finding_path(complexity)

          expect(response.body.squish)
            .to include("The table stops at 1 row and leaves 1 further run out")
          expect(response.parsed_body.css("#complexity-runs tbody tr").size).to eq(1)
        end
      end
    end

    context "with the open-endedness verdict" do
      let(:open_endedness) { Findings::Registry.find("complexity-keeps-rising") }

      def substrate_sweep(key)
        create(:experiment, name: Lab::SWEEPS.fetch(key).fetch(:name), slug: Lab.slug_for(key),
                            param_grid: Lab::SWEEPS.fetch(key).fetch(:param_grid))
      end

      def blank_run(experiment, arm)
        run = create(:run, experiment: experiment, status: "finished", transition_epoch: nil,
                           params: Lab::Schema.run_defaults.merge(arm))
        create(:sample, run: run, epoch: 1_000, values: { "compress_ratio" => 0.9 })
        run
      end

      def arm_run(experiment, arm, lengths)
        run = create(:run, :emerged, experiment: experiment, transition_epoch: 1_000,
                                     params: Lab::Schema.run_defaults.merge(arm))
        lengths.each_with_index do |length, index|
          create(:sample, run: run, epoch: 1_000 + (index * 10),
                          values: { "dominant_instruction_count" => length, "distinct_lineages" => length * 2 })
        end
        run
      end

      it "states each hypothesis in the words of the design and what the counts do not claim" do
        get finding_path(open_endedness)

        expect(response.body.squish)
          .to include("Does complexity keep rising?",
                      "a cost pressure selects for efficient copiers and opens a second niche",
                      "environmental structure raises the plateau the dominant replicator's complexity settles at, " \
                      "refuted if a world whose regions differ plateaus where a uniform world does",
                      "a heterogeneous world keeps more lineages alive after emergence",
                      "room to grow raises the plateau the dominant replicator's complexity settles at, " \
                      "refuted if tapes free to lengthen plateau where fixed-length tapes do",
                      "A peak is a peak at these budgets.",
                      "\"Still rising\" is a description, not a verdict.",
                      "Counts, not effect sizes.",
                      "Every run is read from its own crossing.")
      end

      it "states why the compressed length is not the reading it decides on" do
        get finding_path(open_endedness)

        expect(response.body.squish)
          .to include("zlib wraps an incompressible stream in an 11-byte envelope",
                      "The reading is the cap, not the replicator",
                      "every verdict below is read off the instruction count")
      end

      it "reads the room-to-grow sweep under both detector rules" do
        get finding_path(open_endedness)

        rows = response.parsed_body.css("#max-tape-len-detector-rules tbody tr")
                       .map { |row| row.css("td").map { |cell| cell.text.squish } }

        expect(rows).to eq([%w[64 30 3 3 2], %w[128 90 5 5 3], %w[256 90 4 4 4], %w[512 30 30 1 1]])
        expect(response.body.squish)
          .to include("means 0.754 with a minimum of 0.618, against 0.984 at cap 64",
                      "30 constant crossings are the initial condition",
                      "the 512 arm is the only place the two rules part",
                      "the crossings by cap read 3 / 5 / 4 / 1",
                      "No verdict above moves.")
      end

      it "reads every sweep on both observables and decides it on only one" do
        get finding_path(open_endedness)

        tables = response.parsed_body.css(".table-scroll").pluck("id")

        expect(tables).to include("energy-per-epoch-lineages-arms", "energy-per-epoch-instructions-arms",
                                  "environmental-structure-instructions-arms", "environmental-structure-lineages-arms",
                                  "max-tape-len-instructions-arms", "max-tape-len-lineages-arms")
        expect(response.body.squish)
          .to include("Read but not the hypothesis under test.",
                      "neither support nor refute the hypothesis above")
      end

      it "links the three sweeps it weighs and the baseline finding it is read against" do
        sweeps = %w[energy_per_epoch environmental_structure max_tape_len].map { |key| substrate_sweep(key) }

        get finding_path(open_endedness)

        expect(response.body).to include(finding_path("replicator-complexity-plateau"))
        expect(response.parsed_body.css("p").map { |paragraph| paragraph.text.squish })
          .to include("Read against: Does the replicator keep getting more complicated?")
        sweeps.each { |sweep| expect(response.body).to include(experiment_path(sweep)) }
      end

      it "reads every hypothesis as unresolved with nothing in the database" do
        get finding_path(open_endedness)

        expect(response.parsed_body.css(".badge-info").map(&:text)).to include("unresolved")
        expect(response.body.squish)
          .to include("Not enough emerged seeds to decide it either way",
                      "No run of the three substrate sweeps has emerged in this database yet")
        treated = response.parsed_body.css("#energy-per-epoch-lineages-arms tbody tr").last
        expect(treated.css("td").map { |cell| cell.text.squish }).to eq(["2048", "0", "0", "0", "—", "—", "0"])
      end

      context "with an arm reading above its control" do
        it "reads the hypothesis as supported and names the arm" do
          sweep = substrate_sweep("max_tape_len")
          2.times { arm_run(sweep, { "max_tape_len" => 64 }, [36, 40]) }
          2.times { arm_run(sweep, { "max_tape_len" => 256 }, [60, 120]) }

          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("supported", "reads above the control arm in most of its runs",
                        "has 4 emerged runs, 4 of them carrying a complexity in instructions after the crossing",
                        "The control arm's median peak is 40 instructions")
          expect(response.parsed_body.css("#max-tape-len-instructions-arms tbody tr").size).to eq(4)
        end
      end

      context "with every arm measured and reading where its control does" do
        it "reads the hypothesis as not supported, which is the refutation the design states" do
          sweep = substrate_sweep("environmental_structure")
          2.times { arm_run(sweep, { "structure" => "uniform" }, [36, 44]) }
          2.times { arm_run(sweep, { "structure" => "gradient" }, [36, 44]) }
          2.times { arm_run(sweep, { "structure" => "patchwork" }, [40, 40]) }

          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("not supported",
                        "No arm of the sweep reads above the control arm in most of its runs, and every arm " \
                        "has either been measured or run to 10 seeds with nothing emerging — the refutation " \
                        "condition of the hypothesis")
        end
      end

      context "with an arm nothing has been seeded in" do
        it "stays unresolved and names the arm that could not be tested" do
          sweep = substrate_sweep("environmental_structure")
          2.times { arm_run(sweep, { "structure" => "uniform" }, [36, 44]) }
          2.times { arm_run(sweep, { "structure" => "gradient" }, [36, 40]) }

          get finding_path(open_endedness)

          paragraphs = response.parsed_body.css("p").map { |paragraph| paragraph.text.squish }

          expect(response.body.squish).to include("Not enough emerged seeds to decide it either way")
          expect(paragraphs)
            .to include(a_string_including("Untestable here: patchwork carries fewer than 2 measured runs " \
                                           "without having drawn a blank seed-block either, so the sweep " \
                                           "cannot read as not supported until it is seeded further"))
        end
      end

      context "with a treated arm run to a whole seed-block and nothing emerged" do
        it "names the arm that never emerged and prints its terminal count" do
          sweep = substrate_sweep("environmental_structure")
          2.times { arm_run(sweep, { "structure" => "uniform" }, [36, 44]) }
          2.times { arm_run(sweep, { "structure" => "gradient" }, [36, 40]) }
          10.times { blank_run(sweep, { "structure" => "patchwork" }) }

          get finding_path(open_endedness)

          paragraphs = response.parsed_body.css("p").map { |paragraph| paragraph.text.squish }
          row = response.parsed_body.css("#environmental-structure-instructions-arms tbody tr").last

          expect(paragraphs).to include(a_string_including("Arms that never emerged: patchwork (0 of 10 runs)"))
          expect(response.body.squish).to include("not supported")
          expect(row.css("td").map { |cell| cell.text.squish })
            .to eq(["patchwork never emerged", "10", "0", "0", "—", "0", "0"])
        end
      end

      context "with a control arm run to a whole seed-block and nothing emerged" do
        it "leaves the hypothesis unresolved and says the control never emerged" do
          sweep = substrate_sweep("environmental_structure")
          10.times { blank_run(sweep, { "structure" => "uniform" }) }
          2.times { arm_run(sweep, { "structure" => "gradient" }, [60, 120]) }
          10.times { blank_run(sweep, { "structure" => "patchwork" }) }

          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("The control arm never emerged, so there is no default substrate to read the other " \
                        "arms against",
                        "The control arm never emerged: 10 of its runs reached their last epoch and none of " \
                        "them crossed")
        end
      end

      context "with a crossing no replicator confirmed" do
        it "counts the flagged runs beside the confirmed ones and reads only the confirmed" do
          sweep = substrate_sweep("max_tape_len")
          arm_run(sweep, { "max_tape_len" => 128 }, [36, 40])
          create(:run, experiment: sweep, status: "finished", transition_epoch: 600,
                       params: Lab::Schema.run_defaults.merge("max_tape_len" => 512))

          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("Across the three sweeps the lab holds 2 runs flagged by the detector and " \
                        "1 confirmed by a replicator. 1 of the confirmed ones carry a complexity reading")
        end
      end

      context "with one emerged seed in the control arm" do
        it "keeps the hypothesis unresolved and states the counts behind that" do
          sweep = substrate_sweep("energy_per_epoch")
          arm_run(sweep, { "energy_per_epoch" => 0 }, [36, 40])
          2.times { arm_run(sweep, { "energy_per_epoch" => 2**13 }, [60, 120]) }

          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("Not enough emerged seeds to decide it either way",
                        "has 3 emerged runs, 3 of them carrying a lineage count after the crossing",
                        "The control arm carries fewer than 2 measured runs, so there is nothing to count " \
                        "the other arms against yet")
        end
      end

      context "with the emergence rates of each sweep" do
        it "prints a rate table per hypothesis, with the arm's counts and its p-value" do
          sweep = substrate_sweep("max_tape_len")
          3.times { arm_run(sweep, { "max_tape_len" => 64 }, [36, 40]) }
          7.times { blank_run(sweep, { "max_tape_len" => 64 }) }
          10.times { blank_run(sweep, { "max_tape_len" => 512 }) }

          get finding_path(open_endedness)

          tables = response.parsed_body.css(".table-scroll").pluck("id")
          rows = response.parsed_body.css("#max-tape-len-emergence-rates tbody tr")

          expect(tables).to include("energy-per-epoch-emergence-rates", "environmental-structure-emergence-rates",
                                    "max-tape-len-emergence-rates")
          expect(response.body.squish).to include("How often life emerged")
          expect(rows.first.css("td").map { |cell| cell.text.squish })
            .to eq(["64 control", "10", "3", "3 of 10 (30%)", "—"])
          expect(rows.last.css("td").map { |cell| cell.text.squish })
            .to eq(["512", "10", "0", "0 of 10 (0%)", "p = 0.21"])
        end

        it "reads the rates in one sentence built from the counts" do
          sweep = substrate_sweep("max_tape_len")
          3.times { arm_run(sweep, { "max_tape_len" => 64 }, [36, 40]) }
          7.times { blank_run(sweep, { "max_tape_len" => 64 }) }
          10.times { blank_run(sweep, { "max_tape_len" => 512 }) }

          get finding_path(open_endedness)

          expect(response.parsed_body.css("p").map { |paragraph| paragraph.text.squish })
            .to include("Every treated arm emerged less often than the control arm (0 of 10 against " \
                        "3 of 10); none of the differences reaches p < 0.05.")
        end

        it "badges a difference the test puts below the threshold" do
          sweep = substrate_sweep("max_tape_len")
          10.times { arm_run(sweep, { "max_tape_len" => 64 }, [36, 40]) }
          10.times { blank_run(sweep, { "max_tape_len" => 512 }) }

          get finding_path(open_endedness)

          row = response.parsed_body.css("#max-tape-len-emergence-rates tbody tr").last

          expect(row.css(".badge-warning").map { |badge| badge.text.squish }).to eq(["p < 0.05"])
          expect(response.parsed_body.css("p").map { |paragraph| paragraph.text.squish })
            .to include(a_string_including("the difference at 512 reaches p < 0.05"))
        end

        it "pools the three controls against every treated arm at the bottom" do
          sweep = substrate_sweep("max_tape_len")
          3.times { arm_run(sweep, { "max_tape_len" => 64 }, [36, 40]) }
          7.times { blank_run(sweep, { "max_tape_len" => 64 }) }
          10.times { blank_run(sweep, { "max_tape_len" => 512 }) }

          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("the three control arms emerged in 3 of their 10 terminal runs and every treated " \
                        "arm together in 0 of 10 terminal runs")
        end

        it "says the rate table decides nothing and that a lower rate may be slowness" do
          get finding_path(open_endedness)

          expect(response.body.squish)
            .to include("That table is descriptive. It decides nothing about the plateau",
                        "A lower rate at 20 000 epochs is not an impossibility.")
          expect(response.body).to include(finding_path("mutation-rate-long-horizon"))
        end
      end
    end

    context "with the host-parasite finding" do
      let(:contest_finding) { Findings::Registry.find("complexity-under-contest") }

      it "states the question, the arms and the rule the claim is made by" do
        get finding_path(contest_finding)

        expect(response.body.squish)
          .to include("does complexity keep rising when energy is a contested stock?",
                      "at least 20%", "within ±10% of the first",
                      "theft never evolved")
      end

      it "states the amended measured rule as post hoc" do
        get finding_path(contest_finding)

        expect(response.body.squish)
          .to include("since the core clause cannot be read on it",
                      "<strong>post-hoc amendment</strong>",
                      "clearing both bars reads <em>mixed</em>, never rising",
                      "its runs having mostly fallen, reads <em>neither</em>",
                      "was sampled on, which reads unmeasured")
        expect(response.body).to include(%(<span class="badge badge-warning">partial</span>))
      end

      it "says there is no arm to read and points at the sweep" do
        create(:experiment, name: "Host–parasite economy", slug: "host-parasite")

        get finding_path(contest_finding)

        expect(response.body.squish).to include("has reported a sample in this database, so there is no arm to read")
        expect(response.body).not_to include("No claim yet")
        expect(response.body).to include(experiment_path("host-parasite"))
      end
    end

    context "with the asymmetric-execution skeleton" do
      let(:pending_finding) { Findings::Registry.find("complexity-under-asymmetry") }

      it "states the question, the arms and the rule the claim will be made by" do
        get finding_path(pending_finding)

        expect(response.body.squish)
          .to include("does complexity keep rising when only one partner's code runs?",
                      "at least 20%", "within ±10% of the first",
                      "the two room-to-grow caps whose plateau sweep 8 measured")
      end

      it "states the secondary reading and what would refute the sweep" do
        get finding_path(pending_finding)

        expect(response.body.squish)
          .to include("last decile holds more lineages than the",
                      "controls plateau — same caps, same rate, same world")
        expect(response.body).to include(%(<span class="badge badge-info">open</span>))
      end

      it "says no arm has read yet and points at the sweep the lab will fill it from" do
        create(:experiment, name: "Asymmetric execution", slug: "asymmetric-execution")

        get finding_path(pending_finding)

        expect(response.body.squish).to include("No claim yet: 0 runs of the sweep have finished")
        expect(response.body).to include(experiment_path("asymmetric-execution"))
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
