# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The home page viewer", :js, type: :system do
  def epoch
    find("[data-viewer-target='epoch']").text.delete(",").to_i
  end

  def canvas_has_colour?
    page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.querySelector("canvas")
        if (!canvas.width) return false
        const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data
        return data.some((value, index) => index % 4 !== 3 && value !== 0)
      })()
    JS
  end

  def wait_until(&condition)
    Timeout.timeout(Capybara.default_max_wait_time * 4) do
      sleep(0.1) until condition.call
    end
  end

  it "runs a world the visitor can play, pause, step and reseed" do
    visit root_path

    expect(page).to have_css("canvas")
    expect(page).to have_no_text("could not be loaded")

    wait_until { canvas_has_colour? }
    wait_until { epoch.positive? }

    click_on "Pause"
    stopped = epoch
    sleep 0.5
    expect(epoch).to eq(stopped)

    click_on "Step"
    expect(epoch).to eq(stopped + 1)

    click_on "New seed"
    expect(epoch).to eq(0)

    select "Life", from: "Substrate"
    expect(epoch).to eq(0)
    wait_until { canvas_has_colour? }
  end
end
