# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The Logic finding", type: :system do
  let(:experiment) { logic_experiment }

  context "with the sweep read" do
    before do
      4.times { metabolism_parent }
      Experiments::DescendantSweepBuilderService.call(experiment)
      logic_children(experiment, :full).each do |run|
        logic_sample(run, capability: 3, task_shares: { "echo" => 0.5, "not" => 0.2, "orn" => 0.2 })
      end
      %i[deep_only none].each do |arm|
        logic_children(experiment, arm).each_with_index do |run, index|
          logic_sample(run, task_shares: { "echo" => index.zero? ? 0.2 : 0.0 })
        end
      end
      visit finding_path("paid-logic-climbs-only-read-once-tasks")
    end

    it "states the claim with its status and label" do
      expect(page).to have_css(".finding-meta .badge", text: "negative")
      expect(page).to have_css(".finding-meta .objective-badge", text: "imports an objective")
      expect(page).to have_text("Given a NAND, paid replicators climbed the tasks that read their inputs once")
      expect(page).to have_css(".badge", text: "H-capability-L shown")
      expect(page).to have_css(".badge", text: "H-deep refuted")
      expect(page).to have_css(".badge", text: "H-stones refuted")
      expect(page).to have_css(".badge", text: "H-complexity refuted")
    end

    it "reads each test by parent and under both sensitivity readings" do
      within("#logic-finding-tests") do
        expect(page).to have_text("H-capability-L, full against none: 12 pairs favour full, 0 none and 0 tie, " \
                                  "of 12 measured, p = 0.000244, shown. Every pair of all 4 parents favours full.")
        expect(page).to have_text("H-deep, full against none: 0 pairs favour full, 0 none and 12 tie, of 12 " \
                                  "measured, refuted. By parent, 0 lean to full, 4 tie throughout and 0 lean to none.")
        expect(page).to have_text("With the extinct pairs kept: 12 to 0 with 0 ties, p = 0.000244, shown.")
        expect(page).to have_text("Without the piloted parents: 12 to 0 with 0 ties, p = 0.000244, shown.")
      end
      expect(page).to have_css("#logic-finding-leave-out", text: "No one or two parents carry a shown test")
      expect(page).to have_css("#logic-finding-losses", text: "The full arm lost 0 children to extinction")
    end

    it "describes the ladder each arm climbed" do
      within("#logic-finding-ladder") do
        expect(page).to have_text("of 12 full children, the worlds reached ECHO in 12, NOT in 12, NAND in 0, " \
                                  "AND in 0, ORN in 12, OR in 0, ANDN in 0, and NOR in 0; XOR in 0 and EQU in 0.")
        expect(page).to have_text("Of 12 deep-only children, the worlds reached ECHO in 1 and no other rung.")
        expect(page).to have_text("0 full, 0 deep-only and 0 none children reached a deep rung")
      end
      expect(page).to have_css("#logic-reading")
    end

    it "states what is not claimed" do
      expect(page).to have_text("Nothing about rung 4 on Soup.")
      expect(page).to have_text("Not \"XOR is unreachable\".")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding, negative and importing an objective" do
      card = find(".finding-card", text: "Given a NAND, paid replicators climb every logic task")

      expect(card).to have_css(".badge", text: "negative")
      expect(card).to have_css(".objective-badge", text: "imports an objective")
    end
  end
end
