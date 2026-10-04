# frozen_string_literal: true

require "rails_helper"

# The out-compute label (DESIGN.md §1.4): no finding carries it yet, so a fitness-free finding
# is relabelled for the spec and set beside one left as it is.
RSpec.describe "The imports-a-machine badge", type: :system do
  let(:labelled) { Findings::Registry.find("bff-control").with(imports_machine: true) }
  let(:unlabelled) { Findings::Registry.find("mutation-rate-window") }

  before { stub_const("Findings::Registry::ALL", [labelled, unlabelled]) }

  it "sits beside the labelled finding's status on the index, and nowhere else" do
    visit findings_path

    labelled_card = find(".finding-card", text: labelled.title)
    expect(labelled_card).to have_css(".finding-meta a.badge.machine-badge", text: "imports a machine, not an objective")
    expect(labelled_card).to have_no_css(".objective-badge")
    expect(find(".finding-card", text: unlabelled.title)).to have_no_css(".machine-badge")
  end

  it "explains itself in a tooltip and leads to the glossary" do
    visit findings_path

    badge = find(".finding-card", text: labelled.title).find(".machine-badge")
    expect(badge[:title]).to include("names no computation", "never pooled", "Rung 4 on Soup is unaffected")
    badge.click

    expect(page).to have_css("dt#imports-a-machine", text: "imports a machine, not an objective")
  end

  it "labels the finding's own page, with a line saying what it means" do
    visit finding_path(labelled)

    expect(page).to have_css(".finding-meta .machine-badge")
    expect(page).to have_css("#machine-note", text: "Rung 4 on Soup is unaffected by it.")
    expect(page).to have_no_css("#objective-note")
  end

  it "labels the finding on the home page" do
    visit root_path

    expect(find(".finding-card", text: labelled.title)).to have_css(".machine-badge")
  end

  context "with the finding's sweep and one of its runs in the lab" do
    let(:run) { create(:run, experiment: create(:experiment, slug: labelled.experiment_slug)) }

    it "labels the finding where the sweep page and the run page cite it" do
      visit experiment_path(run.experiment)
      expect(page).to have_css("p", text: "Findings resting on this sweep") { |line| line.has_css?(".machine-badge") }

      visit run_path(run)
      expect(page).to have_css("p", text: "Cited by") { |line| line.has_css?(".machine-badge") }
    end
  end
end
