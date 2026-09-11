# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The page frame on a phone", :js, type: :system do
  let(:phone_width) { 390 }
  let(:experiment) { create(:experiment, name: "Mutation rate", param_grid: { "mutation_rate" => [0.0, 0.001] }) }
  let(:run) { create(:run, experiment: experiment, epochs: 20_000, epochs_done: 7_391) }

  before do
    create(:run, experiment: experiment, status: "finished", transition_epoch: 400, epochs_done: 20_000)
    [100, 4_000, 7_391].each_with_index do |epoch, index|
      create(:sample, run: run, epoch: epoch,
                      values: { "compress_ratio" => 0.98 - (index * 0.01), "distinct_tapes" => 16_384 - index,
                                "replicator_count" => 0, "top_share" => 0.0015, "op_density" => 0.08 })
    end
    # Chrome refuses to size its own window below ~500 CSS px, so the phone viewport has to
    # come from the devtools metrics override; window.resize_to would silently test 500.
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: phone_width, height: 844, deviceScaleFactor: 1, mobile: true)
  end

  # Both widths, so an override that stopped taking effect cannot pass as a page that fits.
  def viewport_and_content_width
    page.evaluate_script("[document.documentElement.clientWidth, document.documentElement.scrollWidth]")
  end

  # One line box per entry: an entry that broke mid-phrase would report two. The rects come
  # from a range over the text, because a flex item reports one box however its text wraps.
  def nav_entry_line_boxes
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.site-nav a'), (link) => {
        const range = document.createRange();
        range.selectNodeContents(link);
        return range.getClientRects().length;
      })
    JS
  end

  def gutter
    page.evaluate_script("document.querySelector('h1').getBoundingClientRect().left")
  end

  it "keeps an experiment inside the viewport, gutter included" do
    visit experiment_path(experiment)

    expect(page).to have_css("table.data-table")
    expect(viewport_and_content_width).to eq([phone_width, phone_width])
    expect(gutter).to be >= 16
  end

  it "keeps a run and its charts inside the viewport, gutter included" do
    visit run_path(run)

    expect(page).to have_css("svg.chart-svg", minimum: 5)
    expect(viewport_and_content_width).to eq([phone_width, phone_width])
    expect(gutter).to be >= 16
  end

  it "keeps how-it-works inside the viewport, instruction table included" do
    visit how_it_works_path

    expect(page).to have_css("table.data-table")
    expect(viewport_and_content_width).to eq([phone_width, phone_width])
    expect(gutter).to be >= 16
  end

  it "wraps the site nav by whole entries" do
    visit how_it_works_path

    expect(nav_entry_line_boxes).to all(eq(1))
    expect(viewport_and_content_width).to eq([phone_width, phone_width])
  end

  it "marks the current nav entry and hides the skip link until it is focused" do
    visit experiments_path

    expect(page).to have_css("nav.site-nav a[aria-current='page']", text: "Experiments")
    expect(page).to have_css(".skip-link", visible: :hidden)
    expect(page).to have_no_css(".skip-link", visible: :visible)

    page.send_keys(:tab)

    expect(page).to have_css(".skip-link", text: "Skip to content")
  end

  it "keeps a finding inside the viewport, diagram and runs table included" do
    sweep = create(:experiment, slug: "mutation-rate", epochs: 20_000,
                                param_grid: { "mutation_rate" => [0.0, 0.001] })
    create(:run, experiment: sweep, status: "finished", transition_epoch: 3_000, epochs_done: 20_000,
                 params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.0))

    visit finding_path(Findings::Registry.find("mutation-rate-window"))

    expect(page).to have_css("svg.chart-svg")
    expect(viewport_and_content_width).to eq([phone_width, phone_width])
    expect(gutter).to be >= 16
  end
end
