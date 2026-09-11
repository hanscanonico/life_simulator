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

  # A caption laid out at the table's width reports more scrollWidth than clientWidth once
  # its text outruns the box, and it slides away with the columns when the box scrolls.
  def caption_boxes
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.table-caption'), (caption) => {
        const box = caption.getBoundingClientRect();
        return [Math.round(box.left), Math.round(box.right), caption.scrollWidth - caption.clientWidth];
      })
    JS
  end

  def scroll_tables_right
    page.execute_script(<<~JS)
      document.querySelectorAll('.table-scroll').forEach((box) => { box.scrollLeft = box.scrollWidth; });
    JS
  end

  def skip_link_covers_wordmark?
    page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector('.skip-link').getBoundingClientRect();
        const mark = document.querySelector('.site-wordmark').getBoundingClientRect();
        return !(link.right <= mark.left || mark.right <= link.left ||
                 link.bottom <= mark.top || mark.bottom <= link.top);
      })()
    JS
  end

  # A planned sweep's description is a sentence or three, so on a phone it takes the whole
  # width of the list rather than the ribbon a term column beside it would leave.
  def prose_definition_widths
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('dl.facts-prose'), (list) => {
        const width = list.getBoundingClientRect().width;
        return Array.from(list.querySelectorAll('dd'),
                          (dd) => Math.round((dd.getBoundingClientRect().width / width) * 100));
      }).flat()
    JS
  end

  it "stacks the planned sweeps' descriptions under their names" do
    visit experiments_path

    expect(page).to have_css("dl.facts-prose dd")
    expect(prose_definition_widths).to all(be >= 99)
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

  it "gives the focused skip link a row of its own above the wordmark" do
    visit experiments_path

    page.send_keys(:tab)

    expect(page).to have_css(".skip-link", text: "Skip to content")
    expect(skip_link_covers_wordmark?).to be(false)
  end

  it "keeps a table's caption out of the table's scrolling box" do
    visit experiment_path(experiment)

    expect(page).to have_css("figcaption.table-caption")
    boxes = caption_boxes
    scroll_tables_right

    expect(caption_boxes).to eq(boxes)
    expect(boxes.map(&:third)).to all(eq(0))
    expect(boxes.map(&:second)).to all(be <= phone_width - 16)
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

RSpec.describe "The prose measure on a desktop", :js, type: :system do
  let(:desktop_width) { 1280 }

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: desktop_width, height: 900, deviceScaleFactor: 1, mobile: false)
  end

  def width_of(selector)
    page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().width")
  end

  def widths_of(selector)
    page.evaluate_script("Array.from(document.querySelectorAll('#{selector}'), (node) => node.getBoundingClientRect().width)")
  end

  it "keeps a finding's prose to a readable measure while its evidence stays wide" do
    sweep = create(:experiment, slug: "mutation-rate", epochs: 20_000,
                                param_grid: { "mutation_rate" => [0.0, 0.001] })
    create(:run, experiment: sweep, status: "finished", transition_epoch: 3_000, epochs_done: 20_000,
                 params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.0))

    visit finding_path(Findings::Registry.find("mutation-rate-window"))

    expect(width_of(".container-narrow p")).to be <= 700
    expect(widths_of("table.data-table")).to all(be > 900)
  end

  it "keeps the findings log to a readable measure" do
    visit findings_path

    expect(width_of(".finding-card p")).to be <= 700
  end
end
