# frozen_string_literal: true

require "rails_helper"

RSpec.describe "A chart on a narrow screen", :js, type: :system do
  let(:rates) { [0.0, *(8..16).map { |exponent| (2**-exponent).to_f }] }
  let(:sweep) { create(:experiment, name: "Mutation rate", epochs: 20_000, param_grid: { "mutation_rate" => rates }) }
  let(:run) { create(:run, experiment: sweep, epochs: 20_000, epochs_done: 20_000) }
  # The rect of an SVG <text> is its em box, around 1.3 times the font size, so 11 px of
  # box is roughly 8.5 px of type — the floor under which a label stops being readable.
  let(:minimum_label_box) { 11 }

  before do
    rates.each_with_index do |rate, index|
      create(:run, experiment: sweep, status: "finished", epochs_done: 20_000,
                   transition_epoch: (index.even? ? nil : 15_560),
                   params: Lab::Schema.run_defaults.merge("mutation_rate" => rate))
    end
    [100, 8_000, 15_560].each_with_index do |epoch, index|
      create(:sample, run: run, epoch: epoch,
                      values: { "compress_ratio" => 0.98 - (index * 0.2), "distinct_tapes" => 16_384 - index,
                                "replicator_count" => index * 3, "top_share" => 0.0015, "op_density" => 0.08 })
    end
    run.update!(transition_epoch: 15_560, status: "finished")
    # Chrome refuses to size its own window below ~500 CSS px, so a phone viewport has to
    # come from the devtools metrics override; window.resize_to would silently test 500.
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: viewport_width, height: 900, deviceScaleFactor: 1, mobile: true)
  end

  def chart_label_boxes
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('svg.chart-svg text'))
        .map((text) => text.getBoundingClientRect())
        .filter((box) => box.width > 0)
        .map((box) => Math.round(box.height))
    JS
  end

  def overlapping_chart_labels
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('svg.chart-svg')).flatMap((svg) => {
        const labels = Array.from(svg.querySelectorAll('text'))
          .map((text) => [text.textContent.trim(), text.getBoundingClientRect()])
          .filter(([, box]) => box.width > 0);
        return labels.flatMap(([text, box], index) => labels.slice(index + 1)
          .filter(([, other]) => box.right > other.left && other.right > box.left &&
                                 box.bottom > other.top && other.bottom > box.top)
          .map(([other]) => [svg.getAttribute('aria-label'), text, other]));
      })
    JS
  end

  def clipped_chart_labels
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('svg.chart-svg')).flatMap((svg) => {
        const frame = svg.getBoundingClientRect();
        return Array.from(svg.querySelectorAll('text'))
          .map((text) => [text.textContent.trim(), text.getBoundingClientRect()])
          .filter(([, box]) => box.width > 0 &&
                               (box.left < frame.left - 0.5 || box.right > frame.right + 0.5 ||
                                box.top < frame.top - 0.5 || box.bottom > frame.bottom + 0.5))
          .map(([text]) => [svg.getAttribute('aria-label'), text]);
      })
    JS
  end

  shared_examples "a chart whose labels can be read" do
    it "draws a run's metrics unclipped and clear of one another" do
      visit run_path(run)

      expect(page).to have_css("svg.chart-svg", minimum: 5)
      expect(overlapping_chart_labels).to eq([])
      expect(clipped_chart_labels).to eq([])
      expect(chart_label_boxes).to all(be >= minimum_label_box)
    end

    it "draws a sweep's phase diagram unclipped and clear of one another" do
      visit experiment_path(sweep)

      expect(page).to have_css("svg.chart-svg")
      expect(overlapping_chart_labels).to eq([])
      expect(clipped_chart_labels).to eq([])
      expect(chart_label_boxes).to all(be >= minimum_label_box)
    end
  end

  context "with a phone viewport" do
    let(:viewport_width) { 390 }

    it_behaves_like "a chart whose labels can be read"
  end

  # The step between the phone sizes and the desktop ones, where a chart already has the
  # page to itself but is drawn twice as wide.
  context "with a viewport just under the desktop grid" do
    let(:viewport_width) { 600 }

    it_behaves_like "a chart whose labels can be read"
  end
end
