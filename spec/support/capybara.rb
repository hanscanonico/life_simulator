# frozen_string_literal: true

require "capybara/rspec"
require "selenium/webdriver"

require_relative "capybara_server_port"

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
# A free port picked at boot, unless CAPYBARA_SERVER_PORT or TEST_ENV_NUMBER pins one.
# See spec/support/capybara_server_port.rb.
Capybara.server_port = CapybaraServerPort.choose

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
end
