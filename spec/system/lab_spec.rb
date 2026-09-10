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

  def tab_hidden(hidden)
    page.execute_script(<<~JS)
      Object.defineProperty(document, "hidden", { configurable: true, get: () => #{hidden} })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
  end

  before { visit lab_path }

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
  end
end
