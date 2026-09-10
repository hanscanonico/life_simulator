# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::IndexPage do
  subject(:page) { described_class.build }

  it "lists every published finding" do
    expect(page.rows.map { |row| row.finding.slug }).to eq(Findings::Registry.all.map(&:slug))
  end

  it "has something to show" do
    expect(page).to be_any
  end

  context "with the sweep in the lab" do
    it "resolves the experiment behind the finding" do
      experiment = create(:experiment, slug: "mutation-rate")

      row = page.rows.find { |candidate| candidate.finding.experiment_slug == "mutation-rate" }

      expect(row.experiment).to eq(experiment)
    end
  end

  context "with the sweep missing" do
    it "keeps the row without an experiment" do
      expect(page.rows.map(&:experiment?)).to all(be(false))
    end
  end
end
