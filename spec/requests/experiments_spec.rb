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

    it "colours each sweep's status badge" do
      experiment.update!(status: "running")

      get experiments_path

      expect(response.body).to include(%(<span class="badge badge-info">running</span>))
    end

    it "reads the rate as the detector's flag rather than as emergence" do
      get experiments_path

      expect(response.body.squish)
        .to include("the share of finished runs the transition detector flagged",
                    "not by itself a replicator census")
      expect(response.body).to include(findings_path)
      expect(response.body).not_to match(/self-replicator emerged/)
    end

    it "links each sweep to the findings resting on it" do
      experiment

      get experiments_path

      expect(response.body).to include(finding_path("radius-locality"),
                                       "Does spatial locality buy emergence?")
    end

    context "with a sweep no finding rests on" do
      it "dashes its finding cell" do
        create(:experiment, name: "Unwritten", slug: "unwritten")

        get experiments_path

        expect(response.body).to include("&mdash;")
      end
    end

    it "lists the sweeps of the programme that are not queued yet" do
      experiment

      get experiments_path

      expect(response.body).to include("Not queued yet", "Instruction set ablations")
      expect(response.body).not_to include("Neighbourhood radius</dt>")
    end

    it "frames the page for a browser and a crawler" do
      get experiments_path

      expect(response.body).to include('<html lang="en-GB">', "<title>Experiments — Life Simulator</title>",
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

    it "links to the findings resting on the sweep" do
      get experiment_path(experiment)

      expect(response.body.squish)
        .to include("Findings resting on this sweep", "Does spatial locality buy emergence?")
      expect(response.body).to include(finding_path("radius-locality"),
                                       %(<span class="badge badge-error">negative</span>))
    end

    context "with a sweep no finding rests on" do
      it "shows neither a link nor an empty heading" do
        unwritten = create(:experiment, name: "Unwritten", slug: "unwritten")

        get experiment_path(unwritten)

        expect(response.body).not_to include("Findings resting on this sweep")
        expect(response.body).not_to include(finding_path("radius-locality"))
      end
    end

    it "spells the transition rate out over the finished runs alone" do
      create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))
      create(:run, experiment: experiment, status: "finished",
                   params: Lab::Schema.run_defaults.merge("radius" => 4))
      create(:run, experiment: experiment, status: "running", transition_epoch: 300,
                   params: Lab::Schema.run_defaults.merge("radius" => 1))

      get experiment_path(experiment)

      expect(response.body).to include("1 of 2 finished runs flagged", "50%",
                                       "0 confirmed by a replicator",
                                       "+1 run still under way already transitioned")
    end

    it "names each run's arm the way the diagram and the arm table do" do
      experiment.update!(param_grid: { "radius" => [1, 2, 0] })
      create(:run, experiment: experiment, seed: 3, params: Lab::Schema.run_defaults.merge("radius" => 0))

      get experiment_path(experiment)

      expect(response.body).to include(%(<td class="numeric mono">well-mixed</td>))
    end

    it "colours each run's status badge" do
      create(:run, experiment: experiment, status: "failed", params: Lab::Schema.run_defaults.merge("radius" => 1))
      create(:run, experiment: experiment, status: "finished", params: Lab::Schema.run_defaults.merge("radius" => 2))
      create(:run, experiment: experiment, status: "running", params: Lab::Schema.run_defaults.merge("radius" => 4))

      get experiment_path(experiment)

      expect(response.body).to include(%(<span class="badge badge-error">failed</span>),
                                       %(<span class="badge badge-success">finished</span>),
                                       %(<span class="badge badge-info">running</span>))
    end

    it "shows each run's queue priority" do
      create(:run, experiment: experiment, priority: 5)

      get experiment_path(experiment)

      expect(response.body).to include("Priority", %(<td class="numeric">5</td>))
    end

    it "counts the crossings a replicator confirmed beside the ones the detector flagged" do
      create(:run, :emerged, experiment: experiment, transition_epoch: 900,
                             params: Lab::Schema.run_defaults.merge("radius" => 2))
      create(:run, experiment: experiment, status: "finished", transition_epoch: 600,
                   params: Lab::Schema.run_defaults.merge("radius" => 4))

      get experiment_path(experiment)

      expect(response.body).to include("2 of 2 finished runs flagged", "1 confirmed by a replicator")
      expect(response.body).to match(%r{900\s*<span class="badge badge-success">confirmed</span>})
      expect(response.body).to match(%r{600\s*<span class="badge badge-info">flagged</span>})
    end

    it "delimits each run's transition epoch and dashes the runs without one" do
      create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, transition_epoch: 12_345,
                   params: Lab::Schema.run_defaults.merge("radius" => 1))
      create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                   params: Lab::Schema.run_defaults.merge("radius" => 2))

      get experiment_path(experiment)

      expect(response.body).to match(%r{<td class="numeric">\s*12,345\s*<span class="badge badge-info">flagged</span>})
      expect(response.body).to match(%r{<td class="numeric">20,000</td>\s*<td class="numeric">\s*—\s*</td>})
    end

    context "with a run the detector flagged and a run only the census counted" do
      def sampled_run(count, transition_epoch: nil)
        run = create(:run, experiment: experiment, status: "finished", transition_epoch: transition_epoch,
                           params: Lab::Schema.run_defaults.merge("radius" => 1),
                           summary: { "replicator_count" => count })
        create(:sample, run: run, epoch: 100, values: { "replicator_count" => count })
        run
      end

      it "badges each run the two observables disagree on" do
        sampled_run(0, transition_epoch: 900)
        sampled_run(12)

        get experiment_path(experiment)

        expect(response.body).to include("Census", %(<span class="badge badge-warning">detector only</span>),
                                         %(<span class="badge badge-info">census only</span>))
        expect(response.body).to match(/<td class="numeric">\s*12\s*<span class="badge badge-info">/)
      end

      it "badges neither run the two observables agree on" do
        sampled_run(12, transition_epoch: 900)
        sampled_run(0)

        get experiment_path(experiment)

        expect(response.body).not_to include("detector only", "census only")
      end

      it "reads the peaks of a full page of runs in one query" do
        25.times { sampled_run(3, transition_epoch: 900) }
        census_queries = []
        collect = lambda do |*, payload|
          census_queries << payload[:sql] if payload[:sql].include?(%("samples")) &&
                                             payload[:sql].include?("replicator_count") &&
                                             payload[:sql].include?("MAX")
        end

        ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
          get experiment_path(experiment)
        end

        expect(census_queries.size).to eq(1)
      end

      it "reads the wider window of a full page of runs in one query" do
        25.times { create(:rescore, run: sampled_run(0, transition_epoch: 900), top_k: 64, replicator_count: 1) }
        wide_queries = []
        collect = ->(*, payload) { wide_queries << payload[:sql] if payload[:sql].include?(%("rescores"."top_k" = )) }

        ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
          get experiment_path(experiment)
        end

        expect(wide_queries.size).to eq(1)
      end
    end

    context "with a run nothing has been sampled from yet" do
      it "leaves its census cell blank" do
        create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 1))

        get experiment_path(experiment)

        expect(response.body).to include("Census")
        expect(response.body).to match(%r{<td class="numeric">\s*—\s*</td>\s*<td class="numeric">\s*</td>})
      end
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

    context "with an arm holding an emerged run, a flagged-only run and a run never flagged" do
      before do
        create(:run, :emerged, experiment: experiment, epochs_done: 20_000, transition_epoch: 200,
                               params: Lab::Schema.run_defaults.merge("radius" => 2))
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, transition_epoch: 800,
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
      end

      it "counts the flagged crossings and the confirmed ones apart" do
        get experiment_path(experiment)

        expect(response.body).to include("Flagged", "Emerged")
        expect(response.body).to match(%r{<span class="mono">2/3</span>\s*<span class="text-muted">\s*67%})
        expect(response.body).to match(%r{<span class="mono">1/3</span>\s*<span class="text-muted">\s*33%})
      end

      it "takes the median and the IQR from the confirmed crossing alone" do
        get experiment_path(experiment)

        arm = response.parsed_body.css("table.data-table tr").find do |row|
          row.at_css("td.mono")&.text == "2"
        end

        expect(arm.css("td").map { |cell| cell.text.squish })
          .to eq(["2", "3", "2/3 67%", "1/3 33%", "200 flagged 500", "200", "2"])
      end

      it "reads the survival curve over the confirmed crossing alone" do
        get experiment_path(experiment)

        expect(response.body).to include("2 — 1 of 3 emerged")
      end

      it "draws the unconfirmed crossing apart from the confirmed one" do
        get experiment_path(experiment)

        diagram = response.parsed_body.at_css("svg")

        expect(diagram.css("g.chart-dots circle title").map(&:text)).to eq(["2: emerged at epoch 200"])
        expect(diagram.css("g.chart-dots-flagged circle title").map(&:text))
          .to eq(["2: flagged at epoch 800, unconfirmed"])
      end

      it "says what the two kinds of marker mean" do
        get experiment_path(experiment)

        expect(response.body.squish)
          .to include("Hollow dots are crossings the detector flagged that nothing confirmed")
      end
    end

    context "with samples behind the finished runs" do
      let!(:flagged) do
        create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
      end
      let!(:unflagged) do
        create(:run, experiment: experiment, status: "finished",
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
      end

      before do
        create(:sample, run: flagged, epoch: 900,
                        values: { "compress_ratio" => 0.4, "replicator_count" => 6 })
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

      it "names the wider census column as a rescore reading, not a changed default" do
        get experiment_path(experiment)

        expect(response.body).to include(%(Replicators at <span class="mono">top_k</span> 64))
      end

      it "leaves the wider census blank for an arm no corpus pass has read" do
        get experiment_path(experiment)

        expect(response.body).to match(arm_row("2", 2, 1, 1, nil))
      end

      context "with the same worlds re-read at top_k 64" do
        before { create(:rescore, run: unflagged, epoch: 900, top_k: 64, replicator_count: 4) }

        it "counts the runs the wider window calls positive beside the locked ones" do
          get experiment_path(experiment)

          expect(response.body).to match(arm_row("2", 2, 1, 1, 1))
        end
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
        expect(lines).to include("arm,n,n_terminal,flagged,relative,both_rules,replicators,both,either_but_not_both",
                                 "2,2,2,1,0,0,1,1,0")
      end

      def arm_row(label, *counts)
        cells = [%(<td class="mono">#{label}</td>),
                 *counts.map { |count| %(<td class="numeric">#{count}</td>) }]

        Regexp.new(cells.map { |cell| Regexp.escape(cell) }.join('\s*'))
      end
    end

    context "with an arm whose emerged runs carry a complexity reading" do
      let(:experiment) do
        create(:experiment, name: "Host-parasite economy", slug: "host-parasite",
                            param_grid: { "economy" => [{ "energy_influx" => 0, "steal_amount" => 0 },
                                                        { "energy_influx" => 512,
                                                          "steal_amount" => 1_024 }] })
      end

      before do
        2.times do
          run = create(:run, :emerged, experiment: experiment, transition_epoch: 100, emergence_epoch: 100,
                                       params: Lab::Schema.run_defaults.merge("energy_influx" => 512,
                                                                              "steal_amount" => 1_024))
          (([12] * 10) + ([40] * 10)).each_with_index do |count, index|
            create(:sample, run: run, epoch: 100 + (index * 10),
                            values: { "compress_ratio" => 0.4, "dominant_instruction_count" => count,
                                      "conserved_core_bytes" => 30, "dominant_compressed_len" => 139,
                                      "steal_rate" => 0.0 })
          end
        end
      end

      it "reads instruction count and conserved core per arm, compressed length beside them" do
        get experiment_path(experiment)

        expect(response.body).to include("Does complexity keep rising, per arm",
                                         "Conserved core", "Compressed length", "keeps rising")
        expect(response.body.squish).to include("12 → 40", "30 → 30", "139 → 139")
      end

      it "reads a steal arm nothing ever stole in as theft that never evolved" do
        get experiment_path(experiment)

        expect(response.body.squish).to include("theft never evolved")
      end
    end

    context "with an asymmetric-execution arm read against its own control" do
      let(:experiment) do
        create(:experiment, name: "Asymmetric execution", slug: "asymmetric-execution",
                            param_grid: { "interaction" => %w[concat host], "max_tape_len" => [128, 256] })
      end

      before do
        %w[concat host].each do |interaction|
          2.times do
            emerged_run(interaction: interaction, lineages: interaction == "host" ? 900 : 120)
          end
        end
      end

      it "names each arm by its interaction mode and cap" do
        get experiment_path(experiment)

        expect(response.body.squish).to include("concat 128", "host 128")
      end

      it "prints the late-run lineage count the secondary reading is taken on" do
        get experiment_path(experiment)

        expect(response.body).to include("Distinct lineages")
        expect(response.body.squish).to include("900 → 900", "120 → 120")
      end

      def emerged_run(interaction:, lineages:)
        run = create(:run, :emerged, experiment: experiment, transition_epoch: 100, emergence_epoch: 100,
                                     params: Lab::Schema.run_defaults.merge("interaction" => interaction,
                                                                            "max_tape_len" => 128))
        (([12] * 10) + ([40] * 10)).each_with_index do |count, index|
          create(:sample, run: run, epoch: 100 + (index * 10),
                          values: { "compress_ratio" => 0.4, "dominant_instruction_count" => count,
                                    "conserved_core_bytes" => 30, "distinct_lineages" => lineages })
        end
      end
    end

    context "with a corpus pass over the sweep" do
      let(:run) do
        create(:run, experiment: experiment, seed: 7, status: "finished",
                     params: Lab::Schema.run_defaults.merge("radius" => 2))
      end

      before do
        create(:rescore, run: run, epoch: 100, top_k: 16, replicator_count: 0)
        create(:rescore, run: run, epoch: 100, top_k: 64, replicator_count: 3)
      end

      it "reports the replicator census at each top_k" do
        get experiment_path(experiment)

        expect(response.body).to include("Replicator census vs", "Newly positive runs")
        expect(response.body).to include("Download rescores (CSV)", rescores_experiment_path(experiment))
      end

      it "streams the readings as CSV" do
        get rescores_experiment_path(experiment)

        lines = response.body.lines.map(&:chomp)
        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment", "radius-rescores.csv")
        expect(lines.first).to eq(
          "run_id,seed,arm,epoch,top_k,replicator_count,top_share,distinct_tapes,compress_ratio,entropy_bits"
        )
        expect(lines.last).to eq("#{run.id},7,radius 2,100,64,3,0.5,12,0.25,3.5")
      end
    end

    context "with a sweep no corpus pass has read" do
      it "shows no replicator census section" do
        create(:run, experiment: experiment, status: "finished",
                     params: Lab::Schema.run_defaults.merge("radius" => 2))

        get experiment_path(experiment)

        expect(response.body).not_to include("Replicator census vs", "Download rescores (CSV)")
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
        create(:run, :emerged, experiment: experiment, epochs_done: 20_000, transition_epoch: 900,
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

      it "counts the emergences the world stayed in, arm by arm" do
        create(:run, :emerged, experiment: experiment, epochs_done: 20_000, transition_epoch: 400,
                               params: Lab::Schema.run_defaults.merge("radius" => 1),
                               persistence: { "census_peak" => 867, "peak_epoch" => 500, "epochs_persisted" => 19_600,
                                              "relapsed" => false })
        create(:run, :emerged, experiment: experiment, epochs_done: 20_000, transition_epoch: 600,
                               params: Lab::Schema.run_defaults.merge("radius" => 1),
                               persistence: { "census_peak" => 42, "peak_epoch" => 900, "epochs_persisted" => 19_400,
                                              "relapsed" => false })
        create(:run, :emerged, experiment: experiment, epochs_done: 20_000, transition_epoch: 800,
                               params: Lab::Schema.run_defaults.merge("radius" => 1),
                               persistence: { "census_peak" => 0, "peak_epoch" => nil, "epochs_persisted" => 200,
                                              "relapsed" => true })

        get experiment_path(experiment)

        expect(response.body.squish).to include("Persisted", "2 of 3", "1 relapsed")
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

    context "with the instruction-cost sweep" do
      let(:experiment) do
        create(:experiment, name: "Instruction cost", slug: "energy-per-epoch", epochs: 20_000,
                            param_grid: Lab::SWEEPS.fetch("energy_per_epoch")[:param_grid])
      end

      let!(:free_run) do
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, transition_epoch: 900,
                     params: Lab::Schema.run_defaults.merge("energy_per_epoch" => 0))
      end
      let!(:priced_run) do
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                     params: Lab::Schema.run_defaults.merge("energy_per_epoch" => 2**11))
      end

      it "reads the budget as an arm of its own, the cost off among them" do
        get experiment_path(experiment)

        expect(response.body).to include("Transition epoch vs energy per epoch", "2048", "Arms of energy per epoch")
      end

      it "draws the survival curves and tabulates the hazard of each budget" do
        get experiment_path(experiment)

        expect(response.body).to include("Time to emergence vs energy per epoch", "P(no emergence)",
                                         "Emergence hazard per arm of energy per epoch", "Run-epochs at risk")
      end

      it "draws what each budget did to descent" do
        create(:sample, run: free_run, epoch: 500, values: { "distinct_lineages" => 128, "top_lineage_share" => 0.2 })
        create(:sample, run: priced_run, epoch: 500, values: { "distinct_lineages" => 4, "top_lineage_share" => 0.8 })

        get experiment_path(experiment)

        expect(response.body).to include("Distinct lineages vs epoch, per arm of energy per epoch",
                                         "Share of the largest lineage vs epoch, per arm of energy per epoch")
      end

      it "draws what each budget did to the dominant replicator's complexity" do
        create(:sample, run: free_run, epoch: 500,
                        values: { "dominant_compressed_len" => 48, "dominant_instruction_count" => 900 })
        create(:sample, run: priced_run, epoch: 500,
                        values: { "dominant_compressed_len" => 30, "dominant_instruction_count" => 120 })

        get experiment_path(experiment)

        expect(response.body).to include("Compressed length of the dominant tape (bytes) " \
                                         "vs epoch, per arm of energy per epoch",
                                         "Instructions in the dominant tape vs epoch, " \
                                         "per arm of energy per epoch")
      end

      context "with runs nothing has been sampled from" do
        it "draws no series at all" do
          get experiment_path(experiment)

          expect(response.body).not_to include("vs epoch, per arm of")
        end
      end
    end

    context "with the environmental-structure sweep" do
      let(:experiment) do
        create(:experiment, name: "Environmental structure", slug: "environmental-structure", epochs: 20_000,
                            param_grid: Lab::SWEEPS.fetch("environmental_structure")[:param_grid])
      end

      let!(:uniform_run) do
        create(:run, :emerged, experiment: experiment, epochs_done: 20_000, transition_epoch: 900,
                               params: Lab::Schema.run_defaults.merge("structure" => "uniform"))
      end
      let!(:patchwork_run) do
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                     params: Lab::Schema.run_defaults.merge("structure" => "patchwork",
                                                            "structure_amplitude" => 0.75))
      end

      it "reads each world as an arm of its own, the uniform one among them" do
        get experiment_path(experiment)

        expect(response.body).to include("Transition epoch vs structure", "patchwork", "Arms of structure")
      end

      it "draws the survival curves and tabulates the hazard of each world" do
        get experiment_path(experiment)

        expect(response.body).to include("Time to emergence vs structure", "P(no emergence)",
                                         "uniform — 1 of 1 emerged", "patchwork — 0 of 1 emerged",
                                         "Emergence hazard per arm of structure", "Run-epochs at risk")
        expect(response.body).not_to include("No run has been observed yet.")
      end

      it "draws what each world did to descent" do
        create(:sample, run: uniform_run, epoch: 500, values: { "distinct_lineages" => 4, "top_lineage_share" => 0.8 })
        create(:sample, run: patchwork_run, epoch: 500,
                        values: { "distinct_lineages" => 128, "top_lineage_share" => 0.2 })

        get experiment_path(experiment)

        expect(response.body).to include("Distinct lineages vs epoch, per arm of structure",
                                         "Share of the largest lineage vs epoch, per arm of structure")
        expect(drawn_arms(response.body)).to include("uniform", "patchwork")
      end

      it "draws what each world did to the dominant replicator's complexity" do
        create(:sample, run: uniform_run, epoch: 500,
                        values: { "dominant_compressed_len" => 30, "dominant_instruction_count" => 120 })
        create(:sample, run: patchwork_run, epoch: 500,
                        values: { "dominant_compressed_len" => 48, "dominant_instruction_count" => 900 })

        get experiment_path(experiment)

        expect(response.body).to include("Compressed length of the dominant tape (bytes) " \
                                         "vs epoch, per arm of structure",
                                         "Instructions in the dominant tape vs epoch, " \
                                         "per arm of structure")
        expect(drawn_arms(response.body)).to include("uniform", "patchwork")
      end

      # The chart's title and legend are rendered beside its empty frame too, so only a
      # path with a plotted `d` says the arm's samples reached the page.
      def drawn_arms(body)
        expect(body).not_to include("No samples recorded yet.")

        drawn = Nokogiri::HTML(body).css("g.chart-steps path.chart-line").select { |path| path["d"].present? }

        drawn.filter_map { |path| path.at_css("title")&.text }
      end
    end

    context "with the room-to-grow sweep" do
      let(:experiment) do
        create(:experiment, name: "Room to grow", slug: "max-tape-len", epochs: 20_000,
                            param_grid: Lab::SWEEPS.fetch("max_tape_len")[:param_grid])
      end

      let!(:fixed_run) do
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000, transition_epoch: 900,
                     params: Lab::Schema.run_defaults.merge("max_tape_len" => 64))
      end
      let!(:roomy_run) do
        create(:run, experiment: experiment, status: "finished", epochs_done: 20_000,
                     params: Lab::Schema.run_defaults.merge("max_tape_len" => 512))
      end

      it "reads each cap as an arm of its own, the fixed-length one among them" do
        get experiment_path(experiment)

        expect(response.body).to include("Transition epoch vs max tape len", "Arms of max tape len")
      end

      it "draws the survival curves and tabulates the hazard of each cap" do
        get experiment_path(experiment)

        expect(response.body).to include("Time to emergence vs max tape len", "P(no emergence)",
                                         "Emergence hazard per arm of max tape len", "Run-epochs at risk")
        expect(response.body).not_to include("No run has been observed yet.")
      end

      it "draws what room to grow did to descent" do
        create(:sample, run: fixed_run, epoch: 500, values: { "distinct_lineages" => 4, "top_lineage_share" => 0.8 })
        create(:sample, run: roomy_run, epoch: 500,
                        values: { "distinct_lineages" => 128, "top_lineage_share" => 0.2 })

        get experiment_path(experiment)

        expect(response.body).to include("Distinct lineages vs epoch, per arm of max tape len",
                                         "Share of the largest lineage vs epoch, per arm of max tape len")
        expect(drawn_arms(response.body)).to include("64", "512")
      end

      it "draws what room to grow did to the dominant replicator's complexity" do
        create(:sample, run: fixed_run, epoch: 500,
                        values: { "dominant_compressed_len" => 30, "dominant_instruction_count" => 120 })
        create(:sample, run: roomy_run, epoch: 500,
                        values: { "dominant_compressed_len" => 48, "dominant_instruction_count" => 900 })

        get experiment_path(experiment)

        expect(response.body).to include("Compressed length of the dominant tape (bytes) " \
                                         "vs epoch, per arm of max tape len",
                                         "Instructions in the dominant tape vs epoch, " \
                                         "per arm of max tape len")
        expect(drawn_arms(response.body)).to include("64", "512")
      end

      # The chart's title and legend are rendered beside its empty frame too, so only a
      # path with a plotted `d` says the arm's samples reached the page.
      def drawn_arms(body)
        expect(body).not_to include("No samples recorded yet.")

        drawn = Nokogiri::HTML(body).css("g.chart-steps path.chart-line").select { |path| path["d"].present? }

        drawn.filter_map { |path| path.at_css("title")&.text }
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
        expect(lines.first).to eq("run_id,seed,status,epochs,epochs_done,transition_epoch,radius," \
                                  "#{Sample::OBSERVABLES.join(',')},emergence_epoch,emergence_witness")
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
