require "application_system_test_case"

# A brand-new dashboard (zero panels) must still expose the grid + Add Panel
# palette so the user can drag-drop their first widget. The legacy
# "Add your first panel" CTA is gone.
module Tiler
  class EmptyDashboardTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Empty #{SecureRandom.hex(3)}")
    end

    test "empty dashboard does NOT show the legacy CTA" do
      visit dashboard_path(@dash.slug)
      assert_no_text "Add your first panel"
      assert_no_text "No panels yet"
    end

    test "Add Panel button toggles the palette on an empty dashboard" do
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-add-panel]", wait: 5
      assert_selector "[data-tiler-palette]", visible: :all, wait: 5
      find("[data-tiler-add-panel]").click
      visible = page.evaluate_script(<<~JS)
        document.querySelector(".tiler-dashboard-shell").classList.contains("tiler-editing-mode")
      JS
      assert visible, "shell should toggle into editing mode showing the palette"
    end

    test "grid container exists on an empty dashboard so gridstack can hydrate" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack.tiler-grid-stack", wait: 5
    end
  end
end
