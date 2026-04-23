require "application_system_test_case"

# F2 — per-dashboard personalization end-to-end:
#   - Settings page exposes a color picker + logo URL input per dashboard
#   - Dashboard show page applies the background color to its --paper token
#     and renders the logo in the page header.
module Tiler
  class DashboardPersonalizationSystemTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Brand #{SecureRandom.hex(3)}")
    end

    test "settings page exposes background color + logo URL inputs per dashboard" do
      visit settings_path
      bg = find("[data-tiler-bg-color]", visible: :all, wait: 5)
      logo = find("[data-tiler-logo-url]", visible: :all, wait: 5)
      assert_equal "color", bg["type"]
      assert_equal "url",   logo["type"]
      assert_equal "background_color", bg["data-tiler--settings-input-key-value"]
      assert_equal "logo_url",         logo["data-tiler--settings-input-key-value"]
    end

    test "dashboard with background_color applies it as inline --paper token" do
      @dash.update!(settings: { background_color: "#102030" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-dashboard", wait: 5
      style = page.evaluate_script(<<~JS)
        document.querySelector(".tiler-dashboard").getAttribute("style") || ""
      JS
      assert_includes style.downcase, "--paper: #102030",
                      "expected inline --paper token (got #{style.inspect})"
    end

    test "dashboard with logo_url renders the logo in the page header" do
      @dash.update!(settings: { logo_url: "https://placehold.co/120x36/png" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-dashboard-logo]", wait: 5
      img = find("[data-tiler-dashboard-logo]")
      assert_equal "https://placehold.co/120x36/png", img["src"]
    end

    test "dashboard without personalization renders no inline --paper and no logo" do
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-dashboard", wait: 5
      style = page.evaluate_script(<<~JS)
        document.querySelector(".tiler-dashboard").getAttribute("style") || ""
      JS
      refute_includes style.downcase, "--paper",
                      "no inline token expected when background_color unset"
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
