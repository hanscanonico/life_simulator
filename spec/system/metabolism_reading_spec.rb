# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The metabolism sweep's page", type: :system do
  let(:experiment) { metabolism_experiment }

  before do
    metabolism_parent
    Experiments::SweepBuilderService.call(experiment)
    reward, no_reward = [true, false].map { |paid| metabolism_children(experiment, reward: paid) }
    reward.first(2).each { |run| metabolism_sample(run, capability: 3, task_shares: { "echo" => 0.5, "inc" => 0.2 }) }
    no_reward.each { |run| metabolism_sample(run, status: "running") }
    visit experiment_path(experiment)
  end

  it "labels the sweep and its reading as importing an objective" do
    expect(page).to have_css("dl.facts .objective-badge", text: "imports an objective")
    expect(page).to have_css("#metabolism-reading h2 .objective-badge")
  end

  it "reads the pairs as pre-registered, interim while a child is under way" do
    within("#metabolism-reading") do
      expect(page).to have_css("h2 .badge", text: "interim")
      expect(page).to have_text("H-capability, reward against no reward: not shown")
      expect(page).to have_text("2 pairs measured on both sides: 2 favour the reward, 0 the twin, 0 tie")
      expect(page).to have_css("#metabolism-pairs tbody tr", count: 3, visible: :all)
    end
  end

  it "tables the ladder per arm" do
    within("#metabolism-reading") do
      expect(page).to have_css("tr", text: /\Aecho\s+2\s+\d[\d,]*\s+0\s+—\z/)
      expect(page).to have_css("tr", text: /\Ainc\s+2\s+\d[\d,]*\s+0\s+—\z/)
      expect(page).to have_css("tr", text: /\Aadd\s+0\s+—\s+0\s+—\z/)
    end
  end
end
