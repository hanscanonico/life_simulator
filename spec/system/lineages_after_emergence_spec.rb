# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The lineages-after-emergence finding", type: :system do
  let(:experiment) { lineage_diversity_experiment }

  before do
    lineage_run(experiment, radius: 0, seed: 1, effective: 1.0)
    lineage_run(experiment, radius: 0, seed: 2, effective: 1.0)
    lineage_run(experiment, radius: 1, seed: 1, effective: 1.0)
    lineage_run(experiment, radius: 1, seed: 2, effective: 1.73)
    lineage_run(experiment, radius: 1, seed: 3, effective: 1.0, share: 0.2)
    [0, 1].each { |radius| (4..6).each { |seed| unemerged(radius, seed: seed) } }
  end

  context "with the sweep read" do
    before { visit finding_path("lineages-after-emergence") }

    it "states the claim from the stored runs" do
      expect(page).to have_css(".badge", text: "negative")
      expect(page).to have_text("No emerged world stayed polyphyletic: of the 4 measured, 3 read monophyletic " \
                                "and 1 between, and the median effective number of lineages is 1 in every read arm.")
      expect(page).to have_text("The worlds that read between one lineage and two: radius 1 seed 2 (1.73).")
      expect(page).to have_text("the locked hypothesis is neither shown nor refuted")
    end

    it "tables the pre-registered reading per arm" do
      within("#lineage-diversity-reading") do
        expect(page).to have_text("final")
        expect(page).to have_css("tr", text: /well-mixed\s+5\s+5\s+2\s+2\s+0\s+0\s+2\s+0\s+1\s+read/)
        expect(page).to have_css("tr", text: /radius 1\s+6\s+6\s+2\s+2\s+0\s+1\s+1\s+0\s+1\s+read/)
      end
    end

    it "reports emergence by reach as descriptive, not as a test" do
      expect(page).to have_text("not a pre-registered test")
      within("#lineage-emergence") do
        expect(page).to have_css("tr", text: /radius 1\s+6\s+3\s+2 of 6\s+1/)
      end
      expect(page).to have_text("Freeman–Halton exact test")
    end

    it "states what is not claimed" do
      expect(page).to have_text("Lineage tags approximate descent.")
      expect(page).to have_text("One world size.")
    end

    it "carries no instrument note" do
      expect(page).to have_no_css("#instrument-note")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding without an instrument-note badge" do
      card = find(".finding-card", text: "After emergence, one lineage takes the world at every reach")

      expect(card).to have_css(".badge", text: "negative")
      expect(card).to have_no_css(".instrument-note-badge")
    end
  end

  def unemerged(radius, seed:)
    create(:run, experiment: experiment, seed: seed, status: "finished",
                 params: Lab::Schema.run_defaults.merge("radius" => radius))
  end
end
