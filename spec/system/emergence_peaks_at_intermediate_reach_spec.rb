# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The emergence-peaks-at-intermediate-reach finding", type: :system do
  let(:experiment) { locality_emergence_experiment }

  context "with the sweep and sweep 12 read" do
    before do
      sweep_arm(experiment, 1, emerged: 1, crossed: 2, first_seed: 91)
      sweep_arm(experiment, 4, emerged: 8, crossed: 8, first_seed: 91)
      sweep_arm(experiment, 8, emerged: 1, crossed: 1, first_seed: 91)
      sweep_arm(experiment, 0, emerged: 0, crossed: 0, first_seed: 91)
      sweep_arm(lineage_diversity_experiment, 0, emerged: 0, crossed: 1, first_seed: 1)
      visit finding_path("emergence-peaks-at-intermediate-reach")
    end

    it "states the claim from the stored runs" do
      expect(page).to have_css(".finding-meta .badge", text: "published")
      expect(page).to have_text("Emergence peaks at an intermediate reach: radius 4 emerged in 8 of 10 fresh " \
                                "worlds, against 1 of 10 at radius 1 and 0 of 10 well-mixed")
      expect(page).to have_css(".badge", text: "H-peak shown")
      expect(page).to have_css(".badge", text: "H-shape shown")
    end

    it "tables the curve with sweep 12 beside it" do
      within("#locality-emergence-curve") do
        expect(page).to have_css("tr", text: /radius 1\s+10\s+2\s+1 of 10\s+10%/)
        expect(page).to have_css("tr", text: /radius 4\s+10\s+8\s+8 of 10\s+80%/)
        expect(page).to have_css("tr", text: /well-mixed\s+10\s+0\s+0 of 10\s+0%\s+1\s+0 of 10/)
      end
    end

    it "says where the totals coincide and why the worlds differ" do
      within("#locality-emergence-coincidence") do
        expect(page).to have_text("At well-mixed this sweep emerged exactly as often as sweep 12 did: 0 of 10.")
        expect(page).to have_text("seeds 91–100 and sweep 12's are 1–10")
        expect(page).to have_text("0 against 1 at well-mixed")
      end
    end

    it "states what is not claimed" do
      expect(page).to have_text("No mechanism.")
      expect(page).to have_text("Well-mixed is not on the radius scale.")
    end

    it "carries no instrument note" do
      expect(page).to have_no_css("#instrument-note")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding without an instrument-note badge" do
      card = find(".finding-card", text: "Emergence peaks at an intermediate reach")

      expect(card).to have_css(".badge", text: "published")
      expect(card).to have_no_css(".instrument-note-badge")
    end
  end

  context "on the radius-locality finding" do
    before { visit finding_path("radius-locality") }

    it "points to the answer on more seeds" do
      expect(page).to have_link("Emergence peaks at an intermediate reach",
                                href: finding_path("emergence-peaks-at-intermediate-reach"))
    end
  end

  def sweep_arm(sweep, radius, emerged:, crossed:, first_seed:)
    10.times do |index|
      share = if index < emerged then 0.9
              elsif index < crossed then 0.2
              end
      locality_run(sweep, radius: radius, share: share, seed: first_seed + index)
    end
  end
end
