require "application_system_test_case"

# Settings link in the global nav + TV mode (hide chrome, show only the grid).
module Tiler
  class SettingsAndTvModeTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      @dash = create_dashboard(name: "TV #{SecureRandom.hex(3)}")
      create_panel(@dash, title: "Clock", widget_type: "clock",
                   x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
    end

    test "global nav has a Settings link next to Data Sources" do
      visit dashboards_path
      assert_selector ".tiler-nav a", text: "Dashboards"
      assert_selector ".tiler-nav a", text: "Data Sources"
      assert_selector ".tiler-nav a", text: "Settings"
    end

    test "Settings page lists each dashboard with a TV-mode toggle" do
      visit settings_path
      assert_text "Settings"
      assert_text(/TV mode/i)
      assert_selector "[data-tiler-tv-toggle][data-dashboard-slug='#{@dash.slug}']", wait: 5
    end

    test "dashboard show via ?tv=1 hides nav + header" do
      visit dashboard_path(@dash.slug, tv: 1)
      assert_no_selector ".tiler-nav"
      assert_no_selector "h1", text: @dash.name
      assert_selector ".grid-stack", wait: 5
    end

    test "dashboard show without TV flag shows full chrome" do
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-nav"
      assert_selector "h1", text: @dash.name
    end

    test "Dashboard.settings persists tv_mode and the show page respects it" do
      @dash.update!(settings: { tv_mode: true }.to_json)
      visit dashboard_path(@dash.slug)
      assert_no_selector ".tiler-nav"
      assert_selector ".grid-stack", wait: 5
    end
  end
end
