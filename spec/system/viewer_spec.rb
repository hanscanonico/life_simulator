# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The home page viewer", :js, type: :system do
  def readout(target)
    find("[data-viewer-target='#{target}']").text
  end

  def epoch
    readout("epoch").delete(",").to_i
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

  def play_label
    find("[data-viewer-target='playLabel']").text
  end

  def emulate_reduced_motion
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia",
                                    features: [{ name: "prefers-reduced-motion", value: "reduce" }])
  end

  # Without JavaScript nothing has compiled the engine yet, which is exactly the state the
  # first-time visitor sees while the wasm module downloads.
  it "announces that the engine is compiling before any script runs", js: false do
    visit root_path

    status = find("[data-viewer-target='status']")
    expect(status.text).to eq("Compiling the world in your browser\u2026")
    expect(status[:role]).to eq("status")
    expect(status[:class]).not_to include("viewer-status--error")
  end

  it "runs a world the visitor can play, pause, step and reseed" do
    visit root_path

    expect(page).to have_css("canvas")
    expect(page).to have_no_text("could not be loaded")

    wait_until { canvas_has_colour? }
    expect(page).to have_no_text("Compiling the world")
    wait_until { epoch.positive? }

    # The readout prints the engine's own metrics_json; nothing computes them in JS.
    wait_until { readout("compressRatio") != "\u2014" }
    expect(readout("compressRatio").to_f).to be_between(0.1, 2.0)
    expect(readout("distinctTapes").delete(",").to_i).to be > 1
    expect(readout("copyRate")).to match(/\A[01]\.\d{3}\z/)

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

  it "leaves the world paused at epoch 0 under prefers-reduced-motion" do
    emulate_reduced_motion
    visit root_path

    wait_until { canvas_has_colour? }

    expect(play_label).to eq("Play")
    sleep 0.5
    expect(epoch).to eq(0)

    click_on "Play"
    wait_until { epoch.positive? }
  end
end
