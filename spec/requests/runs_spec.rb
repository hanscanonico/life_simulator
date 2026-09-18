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
      blanks = "," * (Sample::OBSERVABLES.size - 1)
      expect(lines.second).to eq("100,0.9#{blanks}")
      copy_rate_at = Sample::OBSERVABLES.index("copy_rate")
      expect(lines.third)
        .to eq("200,0.4#{',' * (copy_rate_at - 1)},0.31#{',' * (Sample::OBSERVABLES.size - copy_rate_at - 1)}")
    end

    context "with no sample" do
      it "still sends the header" do
        get samples_run_path(run, format: :csv)

        expect(response.body).to eq("epoch,#{Sample::OBSERVABLES.join(',')}\n")
      end
    end
  end

  describe "GET /runs/:id" do
    context "with a poll of the progress frame" do
      let(:run) { create(:run, :claimed, epochs: 20_000, epochs_done: 1_000) }

      it "answers with the facts alone, not the charts Turbo would discard" do
        create(:sample, run: run, epoch: 100, values: Runs::ShowPage::METRICS.keys.index_with(0.5))

        get run_path(run), headers: { "Turbo-Frame" => "run_progress" }

        expect(response.body.squish).to include("1,000 / 20,000 epochs")
        expect(response.body).not_to include("chart-line", "Download CSV")
      end

      # Turbo throws away a response frame whose src points back at the request that
      # fetched it, and the element on the page keeps its own src across a reload.
      it "leaves the src off the answer" do
        get run_path(run), headers: { "Turbo-Frame" => "run_progress" }

        expect(response.body).to include(%(<turbo-frame id="run_progress">))
      end
    end

    context "with a frame request that is not the progress frame" do
      it "still renders the whole page" do
        get run_path(run), headers: { "Turbo-Frame" => "lab_status" }

        expect(response.body).to include("Download CSV")
      end
    end

    context "with a terminal run" do
      it "polls nothing" do
        get run_path(create(:run, status: "finished"))

        expect(response.body).to include(%(<turbo-frame id="run_progress">))
        expect(response.body).not_to include("frame-poll")
      end
    end

    it "shows the metric series, the seed and the parameters" do
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9, "copy_rate" => 0.0 })
      create(:sample, run: run, epoch: 900, values: { "compress_ratio" => 0.4, "copy_rate" => 0.31 })

      get run_path(run)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Compression ratio", "Copy rate", "<svg", "4242", "mutation_rate")
    end

    context "with a run under an energy stock" do
      it "shows the influx and the stock cap it ran with" do
        stocked = create(:run, params: Lab::Schema.run_defaults.merge("energy_influx" => 64,
                                                                      "energy_stock_cap" => 4_096))

        get run_path(stocked)

        expect(response.body).to include("<dt>energy_influx</dt><dd>64</dd>",
                                         "<dt>energy_stock_cap</dt><dd>4096</dd>")
      end
    end

    context "with a run under an asymmetric interaction" do
      it "shows the execution mode it ran with" do
        hosted = create(:run, params: Lab::Schema.run_defaults.merge("interaction" => "host"))

        get run_path(hosted)

        expect(response.body).to include("<dt>interaction</dt><dd>host</dd>")
      end
    end

    context "with a run whose cells could steal" do
      it "shows the amount a steal moved and the share it destroyed" do
        thieving = create(:run, params: Lab::Schema.run_defaults.merge("energy_influx" => 64,
                                                                       "energy_stock_cap" => 4_096,
                                                                       "steal_amount" => 16,
                                                                       "steal_loss" => 0.25))

        get run_path(thieving)

        expect(response.body).to include("<dt>steal_amount</dt><dd>16</dd>",
                                         "<dt>steal_loss</dt><dd>0.25</dd>")
      end
    end

    context "with a transitioned run whose world held the state" do
      it "shows the census peak, the epochs persisted and no relapse" do
        run.update!(persistence: { "census_peak" => 867, "peak_epoch" => 5_080,
                                   "epochs_persisted" => 14_000, "relapsed" => false })

        get run_path(run)

        expect(response.body.squish).to include("Persistence", "867", "5,080", "14,000")
        expect(response.body).to include(%(<span class="badge badge-success">persisted</span>))
      end
    end

    context "with a transitioned run that climbed back out of the state" do
      it "flags the relapse" do
        run.update!(persistence: { "census_peak" => 0, "peak_epoch" => nil,
                                   "epochs_persisted" => 2_000, "relapsed" => true })

        get run_path(run)

        expect(response.body).to include(%(<span class="badge badge-warning">relapsed</span>))
        expect(response.body.squish).to include("0 (no replicator counted)", "2,000")
      end
    end

    context "with a transitioned run whose samples carry no replicator count" do
      it "reads the census peak as missing rather than as zero" do
        run.update!(persistence: { "census_peak" => nil, "peak_epoch" => nil,
                                   "epochs_persisted" => 2_000, "relapsed" => false })

        get run_path(run)

        expect(response.body.squish).to include("— (not sampled)")
        expect(response.body.squish).not_to include("0 (no replicator counted)")
      end
    end

    context "with a run the detector never flagged" do
      it "says nothing about persistence" do
        run.update!(transition_epoch: nil)

        get run_path(run)

        expect(response.body).not_to include("Persistence")
      end
    end

    it "colours the status badge" do
      run.update!(status: "failed", error: "runner died")

      get run_path(run)

      expect(response.body).to include(%(<span class="badge badge-error">failed</span>))
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

      context "with a numbered arm" do
        let(:run) { create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 1)) }

        it "names the axis the value belongs to" do
          get run_path(run)

          expect(response.body).to include("radius 1, soup substrate, seed")
        end
      end

      context "with a run off the grid" do
        let(:run) { create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 7)) }

        it "names the run's own value" do
          get run_path(run)

          expect(response.body).to include("radius 7, soup substrate, seed")
        end
      end
    end

    it "draws one chart per observable of a run that reported samples, and the two derived ones" do
      [100, 200].each do |epoch|
        create(:sample, run: run, epoch: epoch,
                        values: Runs::ShowPage::METRICS.keys.index_with(0.5)
                                                       .merge("dominant_tape_hash" => "hash#{epoch}"))
      end

      get run_path(run)

      expect(response.body.scan("chart-line").size).to eq(Runs::ShowPage::METRICS.size + 2)
    end

    context "with a run of the instruction-cost sweep" do
      let(:experiment) do
        create(:experiment, name: "Instruction cost", slug: "energy-per-epoch",
                            param_grid: Lab::SWEEPS.fetch("energy_per_epoch")[:param_grid])
      end
      let(:run) do
        create(:run, experiment: experiment, epochs: 20_000, epochs_done: 20_000, transition_epoch: 900,
                     params: Lab::Schema.run_defaults.merge("energy_per_epoch" => 2**11))
      end

      it "draws the lineage and complexity series of a priced world" do
        create(:sample, run: run, epoch: 100, values: Runs::ShowPage::METRICS.keys.index_with(0.5))

        get run_path(run)

        expect(response.body).to include("Distinct lineages", "Share of the largest lineage",
                                         "Copy cost (steps)",
                                         "Compressed length of the dominant tape (bytes)",
                                         "Instructions in the dominant tape",
                                         "Conserved core of the largest lineage (bytes)",
                                         "Instructions in that conserved core", "Steal rate")
      end
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
        create(:sample, run: run, epoch: 200, created_at: recorded_at - 80.seconds)
        create(:sample, run: run, epoch: 1_000, created_at: recorded_at)

        get run_path(run)

        expect(response.body.squish).to include("measured from recorded samples", "10.0 epochs/s",
                                                "Time remaining", "32 minutes")
      end
    end

    context "with a run that accumulated compute" do
      let(:run) { create(:run, :claimed, epochs: 20_000, epochs_done: 10_000, compute_seconds: 3_600.0) }

      it "reads the cost off the compute the runner charged to it" do
        get run_path(run)

        expect(response.body.squish).to include("Cost", "2.78 epochs/compute-second", "1.0 compute hours")
      end
    end

    context "with a run no runner has charged compute to" do
      it "leaves the cost row out rather than dividing by nothing" do
        get run_path(run)

        expect(response.body).not_to include("compute-second")
      end
    end

    context "with a run whose samples all arrived in one batch" do
      let(:run) { create(:run, :claimed, epochs: 20_000, epochs_done: 1_000) }

      it "dashes the rate rather than dividing by the batch's own width" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 100, created_at: recorded_at - 0.05.seconds)
        create(:sample, run: run, epoch: 1_000, created_at: recorded_at)

        get run_path(run)

        expect(response.body.squish).to match(/Rate.*—.*Time remaining.*—/)
        expect(response.body).not_to include("epochs/s")
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

      it "names why each one was taken" do
        create(:snapshot, run: run, epoch: 500, reason: "transition")

        get run_path(run)

        expect(response.body).to include("(transition)")
      end
    end
  end
end
