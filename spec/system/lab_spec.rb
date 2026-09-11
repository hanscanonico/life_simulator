# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The lab status frame", :js, type: :system do
  def mark_page
    page.execute_script("window.labPageMarker = true")
  end

  def page_never_reloaded?
    page.evaluate_script("window.labPageMarker === true")
  end

  def poll_every(milliseconds)
    page.execute_script(
      "document.getElementById('lab_status')" \
      ".setAttribute('data-frame-poll-interval-value', #{milliseconds})"
    )
  end

  def count_frame_reloads
    page.execute_script(<<~JS)
      window.frameReloads = 0
      document.getElementById("lab_status").reload = () => { window.frameReloads += 1 }
    JS
  end

  def frame_reloads = page.evaluate_script("window.frameReloads")

  def tab_hidden(hidden)
    page.execute_script(<<~JS)
      Object.defineProperty(document, "hidden", { configurable: true, get: () => #{hidden} })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
  end

  # The frame's content arrives over its own request, which can beat the import map: every
  # example here drives the poll controller, so none may start before it is listening.
  def await_poll_controller
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script(<<~JS)
        !!(window.Stimulus && window.Stimulus.getControllerForElementAndIdentifier(
          document.getElementById("lab_status"), "frame-poll"
        ))
      JS
    end
  end

  before do
    visit lab_path
    await_poll_controller
  end

  it "resolves the eager frame into the status itself" do
    expect(page).to have_css("h2", text: "Runners holding a run right now")
    expect(page).to have_css("h2", text: "Throughput")
    expect(page).to have_css("h2", text: "Worth a look")
  end

  # The frame polls itself, so a meta refresh would be a second, page-destroying clock.
  it "leaves the page itself to the reader" do
    expect(page).to have_no_css("meta[http-equiv='refresh']", visible: :all)
  end

  it "counts the seconds since the numbers were fetched" do
    expect(page).to have_text(/updated (just now|\d+s ago)/)
    expect(page).to have_text(/updated \d+s ago/)
  end

  it "refetches the frame on its own interval" do
    expect(page).to have_text("The queue is empty")
    mark_page
    poll_every(200)
    create(:run, priority: 5)

    expect(page).to have_text("priority 5")
    expect(page_never_reloaded?).to be(true)
  end

  context "with the Refresh control clicked" do
    it "refetches the frame and nothing else" do
      expect(page).to have_text("The queue is empty")
      mark_page
      create(:run, priority: 5)

      click_on "Refresh"

      expect(page).to have_text("priority 5")
      expect(page_never_reloaded?).to be(true)
    end
  end

  context "with the tab hidden" do
    it "stops polling until the tab comes back" do
      expect(page).to have_text("The queue is empty")
      poll_every(200)
      tab_hidden(true)
      create(:run, priority: 5)

      sleep 1
      expect(page).to have_no_text("priority 5")

      tab_hidden(false)
      expect(page).to have_text("priority 5")
    end

    it "refetches the moment the tab comes back, without waiting for the next tick" do
      expect(page).to have_text("The queue is empty")
      tab_hidden(true)
      create(:run, priority: 5)

      tab_hidden(false)

      expect(page).to have_text("priority 5")
    end
  end

  context "with the page navigated away from" do
    it "stops polling the frame it left behind" do
      expect(page).to have_text("The queue is empty")
      count_frame_reloads
      poll_every(100)
      sleep 0.5
      expect(frame_reloads).to be_positive

      click_on "Experiments"
      expect(page).to have_css("h1", text: "Experiments")
      reloads_on_leaving = frame_reloads

      tab_hidden(false)
      sleep 0.5

      expect(frame_reloads).to eq(reloads_on_leaving)
    end
  end
end
