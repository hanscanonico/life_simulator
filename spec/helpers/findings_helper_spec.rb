# frozen_string_literal: true

require "rails_helper"

RSpec.describe FindingsHelper, type: :helper do
  describe "#findings_run_chart" do
    subject(:chart) do
      helper.findings_run_chart(experiment_slug: "mutation-rate", seed: 1, metric: "compress_ratio")
    end

    context "with the sweep absent from this database" do
      it "renders nothing" do
        expect(chart).to be_nil
      end
    end

    context "with a run of the sweep" do
      let(:experiment) { create(:experiment, name: "Mutation rate", slug: "mutation-rate") }
      let(:run) { create(:run, experiment: experiment, seed: 1, transition_epoch: 200) }

      it "renders nothing while the run has reported no sample" do
        run

        expect(chart).to be_nil
      end

      it "draws the metric and captions it with a link to the run" do
        create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })
        create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })

        expect(chart).to include("<svg", "Compression ratio", run_path(run), "seed 1")
      end

      context "with samples that never carried the metric" do
        it "renders nothing" do
          create(:sample, run: run, epoch: 100, values: { "copy_rate" => 0.31 })

          expect(chart).to be_nil
        end
      end
    end

    context "with one run per arm on the same seed" do
      let(:experiment) { create(:experiment, name: "Mutation rate", slug: "mutation-rate") }

      def run_on(rate)
        create(:run, experiment: experiment, seed: 1,
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => rate))
      end

      it "picks the run of the arm the caller named" do
        other = run_on(0.0)
        wanted = run_on(Lab::EMERGENT_MUTATION_RATE)
        create(:sample, run: other, epoch: 100, values: { "compress_ratio" => 0.99 })
        create(:sample, run: wanted, epoch: 100, values: { "compress_ratio" => 0.4 })

        output = helper.findings_run_chart(experiment_slug: "mutation-rate", seed: 1,
                                           metric: "compress_ratio",
                                           params: { "mutation_rate" => Lab::EMERGENT_MUTATION_RATE })

        expect(output).to include(%(href="#{run_path(wanted)}"))
        expect(output).not_to include(%(href="#{run_path(other)}"))
      end
    end
  end
end
