# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::ShowPage do
  subject(:page) { described_class.build(finding: finding, paginate: paginate) }

  let(:paginate) { ->(scope) { [nil, scope.to_a] } }
  let(:finding) { Findings::Registry.find("mutation-rate-window") }

  context "with the sweep in the lab" do
    let!(:experiment) do
      create(:experiment, slug: "mutation-rate", epochs: 20_000,
                          param_grid: { "mutation_rate" => [0.0, 2.0**-16, 2.0**-8] })
    end

    it "finds the experiment the finding rests on" do
      expect(page.experiment).to eq(experiment)
    end

    it "draws the experiment's own diagrams" do
      expect(page.diagrams.map(&:title)).to eq(["Transition epoch vs mutation rate"])
    end

    it "reads the evidence through the experiment presenter" do
      expect(page.evidence).to be_a(Experiments::ShowPage)
    end

    context "with no finished run" do
      it "is pending" do
        create(:run, experiment: experiment, status: "running")

        expect(page).to be_pending
      end
    end

    context "with a finished run" do
      it "counts it and stops being pending" do
        create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.0))

        expect(page.runs_done).to eq(1)
        expect(page).not_to be_pending
      end
    end

    context "with runs either observable flagged" do
      let!(:transitioned) do
        create(:run, experiment: experiment, seed: 1, status: "finished", transition_epoch: 5_030,
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))
      end
      let!(:counted) do
        create(:run, experiment: experiment, seed: 2, status: "finished",
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.0))
      end

      before do
        create(:sample, run: transitioned, epoch: 5_000,
                        values: { "replicator_count" => 0, "entropy_bits" => 5.6, "copy_rate" => 0.0 })
        create(:sample, run: transitioned, epoch: 5_030,
                        values: { "replicator_count" => 867, "entropy_bits" => 1.2, "copy_rate" => 0.31 })
        create(:sample, run: transitioned, epoch: 6_000,
                        values: { "replicator_count" => 0, "entropy_bits" => 2.4, "copy_rate" => "n/a" })
        create(:sample, run: counted, epoch: 900,
                        values: { "replicator_count" => 14, "entropy_bits" => 6.1, "copy_rate" => 0.02 })
        create(:run, experiment: experiment, seed: 3, status: "finished",
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-16))
      end

      it "rows the flagged runs, transitions first, and leaves the censored one out" do
        expect(page.transitions.map { |row| row.run.seed }).to eq([1, 2])
      end

      it "reads the extrema of each flagged run from its own samples" do
        row = page.transitions.first

        expect(row).to have_attributes(arm_label: "0.00391", transition_epoch: 5_030,
                                       peak_replicator_count: 867.0, peak_epoch: 5_030,
                                       min_entropy_bits: 1.2, max_copy_rate: 0.31)
      end

      it "rows a run the census counted with no transition of its own" do
        expect(page.transitions.last).to have_attributes(transition_epoch: nil, peak_replicator_count: 14.0,
                                                         peak_epoch: 900)
      end

      it "names the swept axis the rows are labelled by" do
        expect(page.arm_column).to eq("Mutation rate")
      end

      it "is not capped" do
        expect(page).not_to be_transitions_capped
      end
    end

    context "with no run flagged" do
      it "has no rows" do
        create(:run, experiment: experiment, status: "finished",
                     params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.0))

        expect(page.transitions).to be_empty
      end
    end

    context "with a transitioned run whose census never left zero" do
      it "reports no epoch for a peak that never happened" do
        run = create(:run, experiment: experiment, status: "finished", transition_epoch: 15_560,
                           params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))
        create(:sample, run: run, epoch: 0, values: { "replicator_count" => 0, "entropy_bits" => 8.0 })
        create(:sample, run: run, epoch: 20_000, values: { "replicator_count" => 0, "entropy_bits" => 4.9 })

        expect(page.transitions.sole).to have_attributes(peak_replicator_count: 0.0, peak_epoch: nil,
                                                         min_entropy_bits: 4.9, max_copy_rate: nil)
      end
    end

    context "with a census that reached its peak twice" do
      it "reports the first epoch that reached it" do
        run = create(:run, experiment: experiment, status: "finished",
                           params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))
        create(:sample, run: run, epoch: 800, values: { "replicator_count" => 2 })
        create(:sample, run: run, epoch: 8_120, values: { "replicator_count" => 2 })

        expect(page.transitions.sole.peak_epoch).to eq(800)
      end
    end

    context "with the rows read from the database" do
      def add_sampled_runs(count)
        count.times do
          run = create(:run, experiment: experiment, status: "finished", transition_epoch: 1_000,
                             params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))
          create(:sample, run: run, epoch: 10, values: { "replicator_count" => 3 })
        end
      end

      def row_query_count
        queries = []
        collect = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
          described_class.build(finding: finding, paginate: paginate).transitions
        end

        queries.size
      end

      it "costs the same number of queries at twelve rows as at four" do
        add_sampled_runs(4)
        four = row_query_count
        add_sampled_runs(8)

        expect(row_query_count).to eq(four)
      end
    end

    context "with more flagged runs than the cap" do
      it "rows the cap and says it is capped" do
        (Findings::ShowPage::MAX_TRANSITIONS + 1).times do |index|
          create(:run, experiment: experiment, status: "finished", transition_epoch: 1_000 + index,
                       params: Lab::Schema.run_defaults.merge("mutation_rate" => 2.0**-8))
        end

        expect(page.transitions.size).to eq(Findings::ShowPage::MAX_TRANSITIONS)
        expect(page.transitions.last.transition_epoch).to eq(1_049)
        expect(page).to be_transitions_capped
      end
    end
  end

  context "with the sweep missing" do
    it "has no experiment and no diagram" do
      expect(page.experiment).to be_nil
      expect(page.diagrams).to be_empty
      expect(page.evidence).to be_nil
      expect(page.transitions).to be_empty
    end

    it "is pending" do
      expect(page).to be_pending
    end
  end
end
