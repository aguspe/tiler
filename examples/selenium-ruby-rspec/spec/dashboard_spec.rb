require_relative "spec_helper"

# Tiler dashboard — Selenium + RSpec example.
#
# Three small, copy-pastable patterns for driving a Tiler dashboard from a
# Selenium suite in your own app. They are not exhaustive tests of Tiler
# itself — see this repo's `test/system/*` for that.
#
# Setup is in the README: install Tiler in your Rails app, seed the demo
# dashboard, run the server, then point TILER_BASE_URL at it.
RSpec.describe "Tiler dashboard" do
  it "dashboard renders at least one panel" do
    visit_dashboard
    # Each persisted panel becomes a .grid-stack-item carrying gs-id="<panel.id>".
    @wait.until { @driver.find_element(css: ".grid-stack-item[gs-id]") }
    expect(@driver.find_elements(css: ".grid-stack-item[gs-id]").length).to be >= 1
  end

  it "clock widget shows the current time" do
    visit_dashboard
    # Widget partials emit class hooks like .tiler-clock-time / .tiler-metric-value.
    # Use those instead of structural selectors — they're stable across releases.
    clock = @wait.until { @driver.find_element(css: ".tiler-clock-time") }
    expect(clock.text).to match(/\d{1,2}:\d{2}:\d{2}/)
  end

  it "clicking a panel header opens the in-page edit drawer" do
    visit_dashboard
    # Tiler edits panels in a slide-over drawer (no full-page nav). Click
    # anywhere on the panel header to open it; the drawer adds .is-open.
    start_url = @driver.current_url
    @wait.until { @driver.find_element(css: "[data-tiler-panel-header]") }.click
    @wait.until { @driver.find_element(css: "[data-tiler-drawer].is-open") }
    expect(@driver.current_url).to eq(start_url)
  end
end
