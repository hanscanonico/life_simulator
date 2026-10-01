# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The Metabolism finding", type: :system do
  let(:experiment) { metabolism_experiment }

  context "with the sweep read" do
    before do
      4.times { metabolism_parent }
      Experiments::DescendantSweepBuilderService.call(experiment)
      metabolism_children(experiment, reward: true).each do |run|
        metabolism_sample(run, capability: 3, last_count: 130, task_shares: { "echo" => 0.5, "inc" => 0.2 })
      end
      metabolism_children(experiment, reward: false).each_with_index do |run, index|
        metabolism_sample(run, capability: index.zero? ? 1 : 0, task_shares: { "echo" => index.zero? ? 0.2 : 0.0 })
      end
      visit finding_path("paid-computation-stops-at-one-step-tasks")
    end

    it "states the claim with its status and label" do
      expect(page).to have_css(".finding-meta .badge", text: "negative")
      expect(page).to have_css(".finding-meta .objective-badge", text: "imports an objective")
      expect(page).to have_text("Paid to compute, replicators took the one-step tasks and stopped there.")
      expect(page).to have_css(".badge", text: "H-capability shown")
      expect(page).to have_css(".badge", text: "H-ladder refuted")
      expect(page).to have_css(".badge", text: "H-complexity shown")
    end

    it "reads each test by parent and without the piloted parents" do
      within("#metabolism-finding-tests") do
        expect(page).to have_text("H-capability: 12 pairs favour the reward, 0 the twin and 0 tie, of 12 measured, " \
                                  "p = 0.000244, shown. Every pair of all 4 parents favours the reward.")
        expect(page).to have_text("H-ladder: 0 pairs favour the reward, 0 the twin and 12 tie, of 12 measured, " \
                                  "refuted. By parent, 0 lean to the reward, 4 tie throughout and 0 lean to the twin.")
        expect(page).to have_text("Without the piloted parents: 12 to 0 with 0 ties, p = 0.000244, shown.")
      end
      expect(page).to have_css("#metabolism-finding-leave-out", text: "No one or two parents carry a shown test")
    end

    it "describes the ladder each arm climbed" do
      within("#metabolism-finding-ladder") do
        expect(page).to have_text("ECHO in 12 of 12 reward children, INC in 12 and DEC in 0, against 1, 0 and 0 " \
                                  "of 12 twins.")
        expect(page).to have_text("0 reward children and 0 twins reached a loop task")
        expect(page).to have_text("At the end of the run only one twin")
      end
      expect(page).to have_css("#metabolism-reading")
    end

    it "states what is not claimed" do
      expect(page).to have_text("Nothing about rung 4 on Soup.")
      expect(page).to have_text("Not open-ended.")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding first, negative and importing an objective" do
      card = first(".finding-card")

      expect(card).to have_text("Paid to compute, replicators take the one-step tasks and stop there")
      expect(card).to have_css(".badge", text: "negative")
      expect(card).to have_css(".objective-badge", text: "imports an objective")
    end
  end
end
