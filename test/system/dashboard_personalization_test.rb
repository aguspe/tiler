require "application_system_test_case"

# F2 — per-dashboard personalization end-to-end:
#   - Settings page exposes 4 theme color pickers + logo URL input per dashboard
#   - Dashboard show emits inline CSS custom properties on .tiler-dashboard
#     (--paper / --paper-2 / --paper-3 / --border) that descendants inherit
#   - Logo renders in page header when set; unsafe URLs are dropped
module Tiler
  class DashboardPersonalizationSystemTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Brand #{SecureRandom.hex(3)}")
    end

    test "settings page exposes 4 theme color inputs + logo URL input" do
      visit settings_path
      %w[page_bg tile_bg tile_header_bg gutter_bg].each do |key|
        picker = find("[data-tiler-theme-color='#{key}']", visible: :all, wait: 5)
        assert_equal "color", picker["type"]
        assert_equal key, picker["data-tiler--settings-input-key-value"]
      end
      logo = find("[data-tiler-logo-url]", visible: :all, wait: 5)
      assert_equal "url", logo["type"]
    end

    test "settings page exposes a Reset theme button" do
      visit settings_path
      assert_selector "[data-tiler-reset-theme]", wait: 5
    end

    test "themed dashboard emits all 4 token overrides as inline style" do
      @dash.update!(settings: {
        page_bg: "#102030", tile_bg: "#445566",
        tile_header_bg: "#778899", gutter_bg: "#aabbcc"
      }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-dashboard", wait: 5
      style = page.evaluate_script(<<~JS)
        document.querySelector(".tiler-dashboard").getAttribute("style") || ""
      JS
      assert_includes style.downcase, "--paper: #102030"
      assert_includes style.downcase, "--paper-2: #445566"
      assert_includes style.downcase, "--paper-3: #778899"
      assert_includes style.downcase, "--border: #aabbcc"
    end

    test "panel surface (--paper-2) override actually paints the tile background" do
      preview = { "_preview" => { "value" => 42 } }.to_json
      panel = create_panel(@dash, title: "M", widget_type: "metric",
                           data_source: nil, x: 0, y: 0, width: 4, height: 2,
                           config: preview)
      @dash.update!(settings: { tile_bg: "#ff0000" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id} .tiler-panel", wait: 5
      bg = page.evaluate_script(<<~JS)
        window.getComputedStyle(
          document.querySelector("turbo-frame#tiler_panel_#{panel.id} .tiler-panel")
        ).backgroundColor
      JS
      # Expect rgb(255, 0, 0) — the inline --paper-2 cascades through the panel.
      assert_equal "rgb(255, 0, 0)", bg
    end

    test "dashboard with logo_url renders the logo in the page header" do
      @dash.update!(settings: { logo_url: "https://placehold.co/120x36/png" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-dashboard-logo]", wait: 5
      img = find("[data-tiler-dashboard-logo]")
      assert_equal "https://placehold.co/120x36/png", img["src"]
    end

    test "dashboard without theme renders no inline style and no logo" do
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-dashboard", wait: 5
      style = page.evaluate_script(<<~JS)
        document.querySelector(".tiler-dashboard").getAttribute("style") || ""
      JS
      refute_includes style, "--paper",
                      "no inline token expected when theme unset"
      assert_no_selector "[data-tiler-dashboard-logo]"
    end

    test "unsafe logo_url (javascript:) is dropped — no <img> rendered" do
      @dash.update!(settings: { logo_url: "javascript:alert(1)" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-dashboard", wait: 5
      assert_no_selector "[data-tiler-dashboard-logo]"
    end
  end
end
