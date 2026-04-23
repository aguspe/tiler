require "application_system_test_case"

# Settings page should give the user a clear path back to the dashboard
# they were last on (or the only dashboard if there's just one).
module Tiler
  class SettingsBackLinkTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "BackLink #{SecureRandom.hex(3)}")
    end

    test "Settings page has a Back-to-dashboard link pointing at the last visited dashboard" do
      visit dashboard_path(@dash.slug)
      visit settings_path
      back = find("[data-tiler-back-dashboard]", wait: 5)
      assert_includes back["href"], dashboard_path(@dash.slug)
      assert_match(/back/i, back.text)
      assert_includes back.text, @dash.name
    end

    test "Settings page falls back to the only dashboard when none was visited" do
      # Fresh session — visit settings directly.
      visit settings_path
      back = find("[data-tiler-back-dashboard]", wait: 5)
      assert_includes back["href"], dashboard_path(@dash.slug)
    end

    test "Settings page has no back link when no dashboards exist" do
      Tiler::Panel.delete_all
      Tiler::Dashboard.delete_all
      visit settings_path
      assert_no_selector "[data-tiler-back-dashboard]"
    end
  end
end
