# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::ShowPage do
  subject(:page) { described_class.build(run: run) }

  let(:run) { create(:run, epochs: 1_000, epochs_done: 250, transition_epoch: 200) }

  describe "#charts" do
    context "with no sample" do
      it "draws every metric as an empty chart" do
        expect(page.charts).to all(be_empty)
      end
    end

    def chart_for(metric) = page.charts[described_class::METRICS.keys.index(metric)]

    it "draws one chart per plottable DESIGN observable" do
      expect(described_class::METRICS.keys)
        .to eq(%w[compress_ratio distinct_tapes top_share replicator_count replicator_share
                  replicator_share_rotated op_density entropy_bits alphabet_size
                  copy_rate reverse_copy_rate distinct_lineages top_lineage_share
                  lineage_effective_count lineages_over_one_percent lineage_variation
                  lineage_variation_oriented copy_cost copy_latency
                  dominant_compressed_len dominant_instruction_count dominant_raw_len
                  conserved_core_bytes conserved_core_ops conserved_core_bytes_oriented
                  conserved_core_ops_oriented steal_rate replicator_pass_rate
                  replicator_count_mean lineage_compressed_len lineage_instruction_count])
      expect(described_class::METRICS.keys).to match_array(Sample::PLOTTABLE)
      expect(page.charts.map(&:title))
        .to eq(described_class::METRICS.values +
               [described_class::COMPRESSIBILITY_TITLE, described_class::TURNOVER_TITLE])
    end

    it "reads the compressed length against the tape's own length" do
      create(:sample, run: run, epoch: 100,
                      values: { "dominant_compressed_len" => 523, "dominant_raw_len" => 512 })
      create(:sample, run: run, epoch: 200,
                      values: { "dominant_compressed_len" => 128, "dominant_raw_len" => 512 })

      expect(page.compressibility_points).to eq([[100, 523 / 512.0], [200, 0.25]])
    end

    it "reads no ratio off a sample an older engine left without a raw length" do
      create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => 523 })

      expect(page.compressibility_points).to be_empty
    end

    it "reads no ratio off a tape of no bytes at all" do
      create(:sample, run: run, epoch: 100,
                      values: { "dominant_compressed_len" => 11, "dominant_raw_len" => 0 })

      expect(page.compressibility_points).to be_empty
    end

    it "names the axes of the two derived charts short enough to be read rotated" do
      axes = page.charts.last(2).map(&:y_label)

      expect(axes).to eq([described_class::COMPRESSIBILITY_AXIS, described_class::TURNOVER_AXIS])
      expect(axes.map(&:length)).to all(be <= 20)
    end

    it "counts the dominant tape as turned over whenever its hash changed" do
      %w[aa aa bb].each_with_index do |hash, index|
        create(:sample, run: run, epoch: 100 + (index * 10), values: { "dominant_tape_hash" => hash })
      end

      expect(page.turnover_points).to eq([[110, 0], [120, 1]])
    end

    it "reads no turnover off samples an older engine left without a hash" do
      create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => 523 })
      create(:sample, run: run, epoch: 110, values: { "dominant_compressed_len" => 523 })

      expect(page.turnover_points).to be_empty
    end

    it "plots the samples of a metric in epoch order" do
      create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      chart = page.charts.first

      expect(chart).not_to be_empty
      expect(chart.marker_pixel).to eq(chart.plot_right.to_f)
    end

    it "skips a metric a sample does not carry" do
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      expect(page.charts.last).to be_empty
    end

    it "draws the copy cost of the samples that carry one" do
      create(:sample, run: run, epoch: 100, values: { "copy_cost" => 1_794 })
      create(:sample, run: run, epoch: 200, values: { "copy_cost" => nil })

      expect(chart_for("copy_cost")).not_to be_empty
    end

    it "draws the complexity of the dominant replicator of the samples that carry one" do
      create(:sample, run: run, epoch: 100,
                      values: { "dominant_compressed_len" => 36, "dominant_instruction_count" => 15 })
      create(:sample, run: run, epoch: 200,
                      values: { "dominant_compressed_len" => nil, "dominant_instruction_count" => nil })

      expect(chart_for("dominant_compressed_len")).not_to be_empty
      expect(chart_for("dominant_instruction_count")).not_to be_empty
    end

    # A sample recorded before the orientation-aware companions existed carries none of
    # them, and a missing reading is no reading — never a share of zero.
    it "draws the orientation-aware companions of the samples that carry them" do
      create(:sample, run: run, epoch: 100, values: { "replicator_count" => 0, "copy_rate" => 0.001 })
      create(:sample, run: run, epoch: 200,
                      values: { "replicator_count" => 0, "copy_rate" => 0.001, "reverse_copy_rate" => 0.7,
                                "replicator_share" => 0.96, "replicator_share_rotated" => 0.97,
                                "dominant_self_replicates" => true })

      expect(%w[replicator_share replicator_share_rotated reverse_copy_rate]
               .map { |metric| Runs::MetricSeriesService.call(run: run, metric: metric) })
        .to eq([[[200, 0.96]], [[200, 0.97]], [[200, 0.7]]])
      expect(chart_for("replicator_share")).not_to be_empty
    end

    # The oriented companions of the lineage readings and of copy_cost arrived after most
    # samples were stored: a sample without them draws no point, never a zero.
    it "draws the oriented companions of the samples that carry them" do
      create(:sample, run: run, epoch: 100, values: { "lineage_variation" => 100.6, "conserved_core_bytes" => 0 })
      create(:sample, run: run, epoch: 200,
                      values: { "lineage_variation" => 100.6, "lineage_variation_oriented" => 0.4,
                                "conserved_core_bytes" => 0, "conserved_core_bytes_oriented" => 126,
                                "conserved_core_ops_oriented" => 20, "copy_cost" => nil,
                                "copy_latency" => 511, "copy_latency_orientation" => "reverse" })

      expect(%w[lineage_variation_oriented conserved_core_bytes_oriented conserved_core_ops_oriented copy_latency]
               .map { |metric| Runs::MetricSeriesService.call(run: run, metric: metric) })
        .to eq([[[200, 0.4]], [[200, 126]], [[200, 20]], [[200, 511]]])
      expect(chart_for("copy_latency")).not_to be_empty
      expect(chart_for("copy_cost")).to be_empty
    end

    describe "#copy_latency_orientation" do
      it "reads the orientation of the latest sample that carries one" do
        create(:sample, run: run, epoch: 100, values: { "copy_latency_orientation" => "forward" })
        create(:sample, run: run, epoch: 200, values: { "copy_latency_orientation" => "reverse" })
        create(:sample, run: run, epoch: 300, values: { "copy_latency_orientation" => nil })

        expect(page.copy_latency_orientation).to eq("reverse")
      end

      context "with samples recorded before the latency existed" do
        it "reads none" do
          create(:sample, run: run, epoch: 100, values: { "copy_cost" => 1_794 })

          expect(page.copy_latency_orientation).to be_nil
        end
      end
    end

    it "draws the conserved core of the samples that carry one" do
      create(:sample, run: run, epoch: 100,
                      values: { "conserved_core_bytes" => 36, "conserved_core_ops" => 15 })
      create(:sample, run: run, epoch: 200,
                      values: { "conserved_core_bytes" => nil, "conserved_core_ops" => nil })

      expect(chart_for("conserved_core_bytes")).not_to be_empty
      expect(chart_for("conserved_core_ops")).not_to be_empty
      expect(Runs::MetricSeriesService.call(run: run, metric: "conserved_core_bytes")).to eq([[100, 36]])
    end

    it "draws the share of interactions that stole" do
      create(:sample, run: run, epoch: 100, values: { "steal_rate" => 0.25 })

      expect(chart_for("steal_rate")).not_to be_empty
      expect(Runs::MetricSeriesService.call(run: run, metric: "steal_rate")).to eq([[100, 0.25]])
    end
  end

  describe "#findings" do
    it "is empty for a sweep no finding cites" do
      expect(page.findings).to be_empty
    end

    context "with a sweep a finding rests on" do
      let(:run) { create(:run, experiment: create(:experiment, name: "Mutation rate", slug: "mutation-rate")) }

      it "cites every finding that names the sweep" do
        expect(page.findings.map(&:slug)).to eq(["mutation-rate-window"])
      end
    end
  end

  describe "#transition_label" do
    it "delimits the epoch of a run that transitioned" do
      expect(page.transition_label).to eq("200")
    end

    context "with no transition yet on a running run" do
      let(:run) { create(:run, status: "running", transition_epoch: nil) }

      it "leaves the door open" do
        expect(page.transition_label).to eq("no emergence yet")
      end
    end

    context "with no transition on a finished run" do
      let(:run) { create(:run, status: "finished", transition_epoch: nil) }

      it "settles the question" do
        expect(page.transition_label).to eq("no emergence")
      end
    end
  end

  describe "#meta_description" do
    let(:run) do
      create(:run, experiment: create(:experiment, name: "BFF control"), seed: 7, status: "finished",
                   epochs: 20_000, epochs_done: 20_000, transition_epoch: 4_000)
    end

    it "names the sweep the way the record spells it, acronym and all" do
      expect(page.meta_description).to start_with("Run ##{run.id} of the BFF control sweep")
    end

    it "states the seed, the progress and the epoch life appeared" do
      expect(page.meta_description)
        .to end_with("seed 7: finished, 20,000 of 20,000 epochs, self-replicators from epoch 4,000.")
    end

    context "with a run that has not transitioned" do
      let(:run) { create(:run, status: "running", transition_epoch: nil) }

      it "leaves the door open the way the page does" do
        expect(page.meta_description).to end_with("no emergence yet.")
      end
    end

    context "with a run inside a swept arm" do
      let(:experiment) do
        create(:experiment, name: "Neighbourhood radius", param_grid: { "radius" => [0, 1, 2] })
      end
      let(:run) { create(:run, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => 0)) }

      it "names the arm the sweep's own tables name" do
        expect(page.arm_label).to eq("well-mixed")
        expect(page.meta_description).to include(" sweep (well-mixed), seed ")
      end
    end
  end

  describe "#charts_empty?" do
    it "is true for a run that has not run an epoch" do
      expect(described_class.build(run: create(:run, epochs_done: 0))).to be_charts_empty
    end

    it "is false once a metric has points" do
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      expect(page).not_to be_charts_empty
    end

    # The runner flushes its first sample batch after 10 s but only heartbeats
    # `epochs_done` after 30 s, so samples routinely arrive before any progress does.
    it "is false for a sample that arrived before the first heartbeat" do
      run = create(:run, :claimed, epochs_done: 0)
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })

      expect(described_class.build(run: run)).not_to be_charts_empty
    end
  end

  describe "#snapshots" do
    it "keeps only the snapshots with a rendered PNG, in epoch order" do
      late = create(:snapshot, run: run, epoch: 300)
      early = create(:snapshot, run: run, epoch: 100)
      create(:snapshot, run: run, epoch: 200, png: nil)

      expect(page.snapshots.map(&:id)).to eq([early.id, late.id])
    end
  end

  describe "#params" do
    it "sorts the parameters so two runs read the same way" do
      expect(page.params.keys).to eq(run.params.keys.sort)
    end
  end

  describe "#epochs_per_compute_second" do
    it "is the epochs done over the compute charged to the run" do
      run.update!(epochs_done: 10_000, compute_seconds: 400.0)

      expect(page.epochs_per_compute_second).to eq(25.0)
    end

    context "with no compute recorded" do
      it "has no cost to report" do
        expect(page.epochs_per_compute_second).to be_nil
      end
    end

    context "with a descendant" do
      it "divides only the epochs it simulated past its parent's" do
        child = create(:run, :descendant, epochs_done: 1_400, compute_seconds: 40.0)

        expect(described_class.build(run: child).epochs_per_compute_second).to eq(10.0)
      end
    end
  end

  describe "#epochs_per_second" do
    it "is the epoch span over the wall-clock span of the samples" do
      recorded_at = Time.current
      create(:sample, run: run, epoch: 200, created_at: recorded_at - 80.seconds)
      create(:sample, run: run, epoch: 1_000, created_at: recorded_at)

      expect(page.epochs_per_second).to eq(10.0)
    end

    context "with a single sample" do
      it "has no span to measure" do
        create(:sample, run: run, epoch: 100)

        expect(page.epochs_per_second).to be_nil
      end
    end

    context "with no sample" do
      it "has nothing to measure" do
        expect(page.epochs_per_second).to be_nil
      end
    end

    context "with two samples of the same batch" do
      it "refuses a zero wall-clock span" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 100, created_at: recorded_at)
        create(:sample, run: run, epoch: 200, created_at: recorded_at)

        expect(page.epochs_per_second).to be_nil
      end

      it "refuses a span narrower than the batch that wrote it" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 100, created_at: recorded_at - 0.02.seconds)
        create(:sample, run: run, epoch: 900, created_at: recorded_at)

        expect(page.epochs_per_second).to be_nil
      end
    end

    context "with samples just under a minute apart" do
      it "refuses a window shorter than the floor it measures against" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 100, created_at: recorded_at - 59.5.seconds)
        create(:sample, run: run, epoch: 900, created_at: recorded_at)

        expect(page.epochs_per_second).to be_nil
      end
    end

    context "with samples a minute apart" do
      it "measures the rate the minute shows" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 100, created_at: recorded_at - 60.seconds)
        create(:sample, run: run, epoch: 700, created_at: recorded_at)

        expect(page.epochs_per_second).to eq(10.0)
      end
    end
  end

  describe "#eta" do
    it "is the remaining epochs at the measured rate" do
      recorded_at = Time.current
      create(:sample, run: run, epoch: 200, created_at: recorded_at - 80.seconds)
      create(:sample, run: run, epoch: 1_000, created_at: recorded_at)

      expect(page.eta).to eq(75.seconds)
    end

    context "with no measured rate" do
      it "says nothing" do
        expect(page.eta).to be_nil
      end
    end

    context "with a finished run" do
      let(:run) { create(:run, status: "finished", epochs: 1_000, epochs_done: 1_000) }

      it "has no time left to report" do
        recorded_at = Time.current
        create(:sample, run: run, epoch: 200, created_at: recorded_at - 80.seconds)
        create(:sample, run: run, epoch: 1_000, created_at: recorded_at)

        expect(page.eta).to be_nil
      end
    end
  end

  describe "#progress" do
    it "is the share of epochs done" do
      expect(page.progress).to eq(25.0)
    end
  end
end
