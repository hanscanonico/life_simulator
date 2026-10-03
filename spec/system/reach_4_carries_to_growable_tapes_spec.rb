# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The reach-cap128 finding", type: :system do
  context "with the sweep and its control read" do
    before do
      sweep = reach_cap128_experiment
      control = host_parasite_control_experiment
      8.times { |index| reach_run(sweep, crossing: 1_000, shares: [0.0, 0.9, 0.9], seed: index + 1) }
      2.times { |index| reach_run(sweep, seed: index + 9) }
      control_run(control, crossing: 1_000, shares: [0.0, 0.9, 0.9], seed: 1)
      9.times { |index| control_run(control, seed: index + 2) }
      visit finding_path("reach-4-carries-to-growable-tapes")
    end

    it "states the claim with its status, the test and the exact p" do
      expect(page).to have_css(".finding-meta .badge", text: "published")
      expect(page).to have_no_css(".finding-meta .objective-badge")
      expect(page).to have_css(".badge", text: "H-reach128 shown")
      expect(page).to have_text("With room to grow, radius 4 emerged in 8 of 10 worlds, against 1 of 10 in the " \
                                "radius-1 control: 8.0 times the rate.")
      expect(page).to have_text("One-sided Fisher exact test, p = 0.00274.")
    end

    it "tables both arms through the sweep's reading" do
      within("#reach-cap128-reading") do
        expect(page).to have_css("tr", text: /radius 4\s+10\s+10\s+10\s+8\s+80%/)
        expect(page).to have_css("tr", text: /control, radius 1\s+10\s+10\s+10\s+1\s+10%/)
        expect(page).to have_text("p = 0.00274")
      end
    end

    it "counts the parent pool without locking a rule" do
      within("#reach-cap128-finding-parents") do
        expect(page).to have_text("Radius 4 gives 8 of them, against 1 in the control")
        expect(page).to have_text("no later sweep's parent rule is locked by this reading")
      end
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding first, without an objective badge" do
      card = first(".finding-card")

      expect(card).to have_text("On growable tapes, a reach of 4 emerges more than ten times as often as radius 1")
      expect(card).to have_css(".badge", text: "published")
      expect(card).to have_no_css(".objective-badge")
    end
  end

  context "on the locality-emergence finding" do
    before { visit finding_path("emergence-peaks-at-intermediate-reach") }

    it "points to the reading on growable tapes" do
      expect(page).to have_link("On growable tapes, a reach of 4 emerges more than ten times as often as radius 1",
                                href: finding_path("reach-4-carries-to-growable-tapes"))
    end
  end
end
