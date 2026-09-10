# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The page frame on a phone", :js, type: :system do
  let(:experiment) { create(:experiment, name: "Mutation rate", param_grid: { "mutation_rate" => [0.0, 0.001] }) }
  let(:run) { create(:run, experiment: experiment, epochs: 20_000, epochs_done: 7_391) }

  before do
    create(:run, experiment: experiment, status: "finished", transition_epoch: 400, epochs_done: 20_000)
    [100, 4_000, 7_391].each_with_index do |epoch, index|
      create(:sample, run: run, epoch: epoch,
                      values: { "compress_ratio" => 0.98 - (index * 0.01), "distinct_tapes" => 16_384 - index,
                                "replicator_count" => 0, "top_share" => 0.0015, "op_density" => 0.08 })
    end
    page.driver.browser.manage.window.resize_to(390, 844)
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  def gutter
    page.evaluate_script("document.querySelector('h1').getBoundingClientRect().left")
  end

  it "keeps an experiment inside the viewport, gutter included" do
    visit experiment_path(experiment)

    expect(page).to have_css("table.data-table")
    expect(horizontal_overflow).to be <= 0
    expect(gutter).to be >= 16
  end

  it "keeps a run and its charts inside the viewport, gutter included" do
    visit run_path(run)

    expect(page).to have_css("svg.chart-svg", minimum: 5)
    expect(horizontal_overflow).to be <= 0
    expect(gutter).to be >= 16
  end
end
