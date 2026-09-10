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
  end

  context "with the sweep missing" do
    it "has no experiment and no diagram" do
      expect(page.experiment).to be_nil
      expect(page.diagrams).to be_empty
      expect(page.evidence).to be_nil
    end

    it "is pending" do
      expect(page).to be_pending
    end
  end
end
