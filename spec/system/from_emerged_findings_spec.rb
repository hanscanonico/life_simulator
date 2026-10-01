# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The from-emerged findings", type: :system do
  let(:experiment) { from_emerged_experiment }

  before do
    [from_emerged_parent(seed: 120), from_emerged_parent(seed: 121)]
    Experiments::DescendantSweepBuilderService.call(experiment)
    experiment.runs.each { |run| from_emerged_sample(run) }
    [1, 2].each do |index|
      from_emerged_children(experiment, index).each do |run|
        run.samples.delete_all && from_emerged_sample(run, last: 2_000)
      end
    end
  end

  context "with the rung-3 finding" do
    before { visit finding_path("copying-gets-faster-under-an-economy") }

    it "states the claim with its effect size" do
      expect(page).to have_css(".badge", text: "published")
      expect(page).to have_text("Over the held-out children, the median ratio of last-decile to first-decile " \
                                "copy_latency was 0.5 under economy 2048 and 0.5 under economy 8192, against 1 " \
                                "in the continuation.")
      expect(page).to have_text("6 of 6 pairs favour the treatment and 0 the continuation, one-sided sign test " \
                                "p = 0.0156")
    end

    it "tables the effect per treatment and the agreement per parent" do
      expect(page).to have_css("tr", text: /economy 8192\s+6\s+4,000\s+2,000\s+0\.5\s+6/)
      expect(page).to have_text("The treatment wins the majority of its pairs in 2 of 2 held-out parents.")
    end

    it "states what is not claimed" do
      expect(page).to have_text("Not in situ.")
      expect(page).to have_text("The mechanism is not identified.")
      expect(page).to have_text("No halting copier.")
    end

    it "carries no instrument note" do
      expect(page).to have_no_css("#instrument-note")
    end
  end

  context "with the rung-4 finding" do
    before { visit finding_path("complexity-from-an-emerged-start") }

    it "states that the economy does not keep complexity rising" do
      expect(page).to have_css(".badge", text: "negative")
      expect(page).to have_text("From an emerged start, neither energy economy can be read as keeping complexity " \
                                "rising, and on the held-out survivors the complexity signal does not replicate.")
      expect(page).to have_text("6 of 6 continuations kept their replicators over 20 000 more epochs.")
    end

    it "lists the original and the held-out complexity verdicts" do
      expect(page).to have_text("H-host, host mode")
      expect(page).to have_text("H4-survivors, held out, economy 8192")
      within("#descendant-reading") { expect(page).to have_text("final") }
    end

    it "carries no instrument note" do
      expect(page).to have_no_css("#instrument-note")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists both findings without an instrument-note badge" do
      cards = [["Under an energy economy, the dominant replicator copies itself faster", "published"],
               ["From an emerged start, an energy economy does not keep complexity rising", "negative"]]

      cards.each do |title, status|
        card = find(".finding-card", text: title)
        expect(card).to have_css(".badge", text: status)
        expect(card).to have_no_css(".instrument-note-badge")
      end
    end
  end
end
