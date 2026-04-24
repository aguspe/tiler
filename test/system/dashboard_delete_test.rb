require "application_system_test_case"

# Delete a dashboard from the index page: hover the card → × button appears →
# click → confirmation modal → confirm → dashboard removed via DELETE.
module Tiler
  class DashboardDeleteTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @keep   = create_dashboard(name: "Keep #{SecureRandom.hex(3)}")
      @victim = create_dashboard(name: "Victim #{SecureRandom.hex(3)}")
    end

    test "every card carries a hidden-by-default delete affordance" do
      visit dashboards_path
      assert_selector "[data-tiler-dashboard-card='#{@victim.slug}'] [data-tiler-dashboard-delete]",
                      visible: :all, wait: 5
      opacity = page.evaluate_script(<<~JS)
        window.getComputedStyle(
          document.querySelector("[data-tiler-dashboard-card='#{@victim.slug}'] [data-tiler-dashboard-delete]")
        ).opacity
      JS
      assert_equal "0", opacity, "delete button must be invisible until hover"
    end

    test "the × button hover reveals it and is wired to the modal controller" do
      visit dashboards_path
      btn = find("[data-tiler-dashboard-card='#{@victim.slug}'] [data-tiler-dashboard-delete]",
                 visible: :all, wait: 5)
      assert_includes btn["data-controller"], "tiler--modal"
      assert_includes btn["data-action"],     "click->tiler--modal#open"
      assert_equal    "delete", btn["data-tiler--modal-method-value"]
      assert_includes btn["data-tiler--modal-action-value"], "/dashboards/#{@victim.slug}"
      assert_match    /delete/i, btn["data-tiler--modal-confirm-label-value"]
    end

    test "clicking × opens a custom modal (not native confirm) before destroy" do
      visit dashboards_path
      page.execute_script(<<~JS)
        document.querySelector("[data-tiler-dashboard-card='#{@victim.slug}'] [data-tiler-dashboard-delete]").click();
      JS
      assert_selector ".tiler-modal-overlay", wait: 5
      assert_text(/delete .+#{Regexp.escape(@victim.name)}/i)
      # Cancel keeps the dashboard.
      find("[data-tiler-modal-cancel]").click
      assert_no_selector ".tiler-modal-overlay"
      assert Tiler::Dashboard.exists?(slug: @victim.slug), "Cancel must NOT delete"
    end

    test "confirming the modal DELETEs the dashboard and the card disappears" do
      visit dashboards_path
      page.execute_script(<<~JS)
        document.querySelector("[data-tiler-dashboard-card='#{@victim.slug}'] [data-tiler-dashboard-delete]").click();
      JS
      find("[data-tiler-modal-confirm]", wait: 5).click
      Timeout.timeout(5) { sleep 0.05 until !Tiler::Dashboard.exists?(slug: @victim.slug) }
      refute Tiler::Dashboard.exists?(slug: @victim.slug),
             "Victim dashboard should be deleted from the database"
      assert Tiler::Dashboard.exists?(slug: @keep.slug),
             "Other dashboards must NOT be touched"
      assert_no_selector "[data-tiler-dashboard-card='#{@victim.slug}']", wait: 5
    end
  end
end
