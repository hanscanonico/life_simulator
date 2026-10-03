# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The Meta-stack finding", type: :system do
  context "with the sweep read" do
    let(:experiment) { meta_stack_experiment }
    let(:logic) { logic_experiment }
    let!(:parents) { Array.new(4) { metabolism_parent } }

    before do
      Experiments::DescendantSweepBuilderService.call(logic)
      Experiments::DescendantSweepBuilderService.call(experiment)
      meta_stack_children(experiment, :meta_stack).each_with_index do |run, index|
        deep = index < 5
        meta_stack_sample(run, capability: 3, deep: deep ? 1 : 0,
                               task_shares: { "echo" => 0.5, "xor" => deep ? 0.2 : 0.0 })
      end
      (experiment.runs + logic.runs).each { |run| meta_stack_sample(run) if run.samples.none? }
      visit finding_path("paid-parts-assemble-deep-logic-on-a-stack-nand")
    end

    it "states the claim with its status and label" do
      expect(page).to have_css(".finding-meta .badge", text: "published")
      expect(page).to have_css(".finding-meta .objective-badge", text: "imports an objective")
      expect(page).to have_text("With a stack NAND on a metabolism tape, paid parts assembled the logic rungs " \
                                "that need an input twice.")
      %w[H-deep-Ms H-stones-Ms H-stack H-capability-M].each do |hypothesis|
        expect(page).to have_css(".badge", text: "#{hypothesis} shown")
      end
      expect(page).to have_css(".badge", text: "H-deep-M refuted")
      expect(page).to have_css(".badge", text: "H-decouple refuted")
    end

    it "reads each test by parent, under both re-readings, with the parents that carry it" do
      within("#meta-stack-finding-tests") do
        expect(page).to have_text("H-deep-Ms, meta-stack against logic-none: 5 pairs favour meta-stack, 0 " \
                                  "logic-none and 7 tie, of 12 measured, p = 0.0312, shown. By parent, 2 lean " \
                                  "to meta-stack, 2 tie throughout and 0 lean to logic-none.")
        expect(page).to have_text("H-capability-M, meta-stack against logic-none: 12 pairs favour meta-stack, " \
                                  "0 logic-none and 0 tie, of 12 measured, p = 0.000244, shown. Every pair of " \
                                  "all 4 parents favours meta-stack.")
      end
      expect(page).to have_css("#meta-stack-finding-leave-out",
                               text: "H-deep-Ms rests on parents run #{parents.first.id} or run #{parents.second.id}")
      expect(page).to have_css("#meta-stack-finding-leave-out",
                               text: "Re-read as H-deep-Ms, unpiloted parents, it rests on parents " \
                                     "run #{parents.first.id} or run #{parents.second.id}")
    end

    it "lists the deep children beside the other arms and draws the sweep's section" do
      expect(page).to have_css("#meta-stack-finding-deep",
                               text: "5 meta-stack children of 12, from 2 parents, held XOR or EQU")
      expect(page).to have_css("#meta-stack-finding-deep",
                               text: "0 meta-stack-deep-only, 0 meta-inplace, 0 logic-none, and 0 logic-full")
      expect(page).to have_css("#meta-stack-reading")
    end

    it "states the offline readings and what is not claimed" do
      expect(page).to have_text("The substitution distance says nothing here.")
      expect(page).to have_text("Nothing about rung 4 on Soup.")
      expect(page).to have_text("Not open-ended.")
    end
  end

  context "on the findings index" do
    before { visit findings_path }

    it "lists the finding, published and importing an objective" do
      card = find(".finding-card", text: "With a stack NAND on a metabolism tape, paid parts assemble")

      expect(card).to have_css(".badge", text: "published")
      expect(card).to have_css(".objective-badge", text: "imports an objective")
    end
  end
end
