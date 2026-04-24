require "selenium-webdriver"
require "rspec"

TILER_BASE_URL       = ENV.fetch("TILER_BASE_URL",       "http://127.0.0.1:3000")
TILER_DASHBOARD_SLUG = ENV.fetch("TILER_DASHBOARD_SLUG", "demo")

RSpec.configure do |config|
  config.before(:each) do
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new") unless ENV["HEADED"] == "1"
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,1000")
    @driver = Selenium::WebDriver.for(:chrome, options: options)
    @wait   = Selenium::WebDriver::Wait.new(timeout: 10)
  end

  config.after(:each) do
    @driver&.quit
  end

  def visit_dashboard
    @driver.navigate.to "#{TILER_BASE_URL}/tiler/dashboards/#{TILER_DASHBOARD_SLUG}"
    @wait.until { @driver.find_element(css: ".tiler-grid-stack") }
  end
end
