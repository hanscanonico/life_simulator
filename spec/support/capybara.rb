# frozen_string_literal: true

require "capybara/rspec"
require "selenium/webdriver"

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,900")
  options.add_argument("--lang=en")
  options.add_preference("intl.accept_languages", "en-US,en")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_max_wait_time = 5

Capybara.server_host = "localhost"
# Offset by TEST_ENV_NUMBER so parallel workers (each booting their own
# headless Chrome) don't collide on the same port.
Capybara.server_port = 3001 + ENV.fetch("TEST_ENV_NUMBER", "0").to_i

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
end
