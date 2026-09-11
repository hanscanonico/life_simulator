# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The run progress frame", :js, type: :system do
  def mark_page
    page.execute_script("window.runPageMarker = true")
  end

  def page_never_reloaded?
    page.evaluate_script("window.runPageMarker === true")
  end

  def poll_every(milliseconds)
    page.execute_script(
      "document.getElementById('run_progress')" \
      ".setAttribute('data-frame-poll-interval-value', #{milliseconds})"
    )
  end

  # The frame reloads itself the moment the page opens, so nothing may drive the poll
  # before the import map has landed and the controller is listening.
  def await_poll_controller
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script(<<~JS)
        !!(window.Stimulus && window.Stimulus.getControllerForElementAndIdentifier(
          document.getElementById("run_progress"), "frame-poll"
        ))
      JS
    end
  end

  context "with a run still going" do
    let(:run) { create(:run, :claimed, status: "running", epochs: 1_000, epochs_done: 100) }

    before do
      visit run_path(run)
      await_poll_controller
    end

    it "picks the new progress up without a page load" do
      expect(page).to have_text("100 / 1,000 epochs (10.0%)", normalize_ws: true)
      mark_page
      poll_every(200)

      run.update!(epochs_done: 500, transition_epoch: 420)

      expect(page).to have_text("500 / 1,000 epochs (50.0%)", normalize_ws: true)
      expect(page).to have_text("Transition epoch")
      expect(page).to have_text("420")

      run.update!(epochs_done: 900)

      expect(page).to have_text("900 / 1,000 epochs (90.0%)", normalize_ws: true)
      expect(page_never_reloaded?).to be(true)
    end

    it "leaves the rest of the page outside the frame" do
      expect(page).to have_css("turbo-frame#run_progress dl.facts")
      expect(page).to have_no_css("turbo-frame#run_progress", text: "Download CSV")
      expect(page).to have_link("Download CSV")
    end
  end

  context "with a finished run" do
    it "costs no request at all" do
      run = create(:run, status: "finished", epochs: 1_000, epochs_done: 1_000)

      visit run_path(run)

      expect(page).to have_text("1,000 / 1,000 epochs (100.0%)", normalize_ws: true)
      expect(page).to have_no_css("turbo-frame#run_progress[src]", visible: :all)
      expect(page).to have_no_css("turbo-frame#run_progress[data-controller]", visible: :all)
    end
  end
end
