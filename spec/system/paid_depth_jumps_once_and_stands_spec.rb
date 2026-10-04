# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The topless-rise finding", type: :system do
  context "with the sweep read" do
    let(:experiment) { topless_rise_experiment }
    let!(:parents) { topless_rise_parents }

    before do
      Experiments::DescendantSweepBuilderService.call(experiment)
      topless_rise_children(experiment, :rise).each_with_index do |run, index|
        topless_rise_sample(run, fifth: 9, last: index.zero? ? 10 : 9)
      end
      topless_rise_children(experiment, :capped).each { |run| topless_rise_sample(run, fifth: 7, last: 8) }
      topless_rise_children(experiment, :none).each { |run| topless_rise_sample(run, fifth: 0) }
      visit finding_path("paid-depth-jumps-once-and-stands")
    end

    it "states the claim with its status and label" do
      expect(page).to have_css(".finding-meta .badge", text: "negative")
      expect(page).to have_css(".finding-meta .objective-badge", text: "imports an objective")
      expect(page).to have_text("Paid for depth, the soup did not keep climbing.")
      expect(page).to have_css(".badge", text: "H-rise not shown")
      expect(page).to have_css(".badge", text: "H-rise-paid refuted")
    end

    it "reads each test with both re-readings, and names the late risers" do
      rise = topless_rise_children(experiment, :rise).first

      within("#topless-rise-finding-tests") do
        expect(page).to have_text("With the extinct pairs kept: 1 to 0 with 2 ties, p = 0.5")
        expect(page).to have_text("On the deep parents' children: 0 to 0 with 0 ties")
      end
      within("#topless-rise-finding-risers") do
        expect(page).to have_link("run #{rise.id}", href: run_path(rise))
        expect(page).to have_text("against 3 capped and 0 none")
      end
      expect(page).to have_css("#topless-rise-reading")
    end

    it "states the offline reading and what it means" do
      expect(page).to have_text("The one rise child that rose late is a re-climb, not a climb.")
      expect(page).to have_text("The climb stops.")
      expect(page).to have_text("Nothing about rung 4 on Soup.")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding first, negative and importing an objective" do
      card = first(".finding-card")

      expect(card).to have_text("Paid for depth, the soup jumps once and stands")
      expect(card).to have_css(".badge", text: "negative")
      expect(card).to have_css(".objective-badge", text: "imports an objective")
    end
  end
end
