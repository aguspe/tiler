require "application_system_test_case"

# F1 — double-click the dashboard title to rename it inline. Saves via
# PATCH /api/v1/dashboards/:slug; reverts on validation failure.
module Tiler
  class DashboardInlineRenameTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Original #{SecureRandom.hex(3)}")
    end

    test "title is wired with inline-edit controller and a hint title attr" do
      visit dashboard_path(@dash.slug)
      title = find("[data-tiler-dashboard-title]", wait: 5)
      assert_includes title["data-controller"], "tiler--inline-edit"
      assert_includes title["data-action"], "dblclick->tiler--inline-edit#edit"
      assert_match(/double-click/i, title["title"])
    end

    test "double-click → type → Enter persists the new name" do
      visit dashboard_path(@dash.slug)
      title = find("[data-tiler-dashboard-title]", wait: 5)
      title.double_click
      # The element becomes contenteditable; replace its text via JS to avoid
      # selenium's input-into-contenteditable flakiness, then trigger blur.
      page.execute_script(<<~JS)
        var el = document.querySelector("[data-tiler-dashboard-title]");
        el.textContent = "Renamed via dblclick";
        el.dispatchEvent(new FocusEvent("blur"));
      JS
      Timeout.timeout(5) { sleep 0.1 until @dash.reload.name == "Renamed via dblclick" }
      assert_equal "Renamed via dblclick", @dash.name
    end

    test "Esc cancels — name stays unchanged" do
      original = @dash.name
      visit dashboard_path(@dash.slug)
      title = find("[data-tiler-dashboard-title]", wait: 5)
      title.double_click
      page.execute_script(<<~JS)
        var el = document.querySelector("[data-tiler-dashboard-title]");
        el.textContent = "Should not stick";
        el.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      JS
      sleep 0.3
      assert_equal original, @dash.reload.name
      assert_equal original, find("[data-tiler-dashboard-title]").text.strip
    end

    test "empty name is rejected — element reverts and shows a flash" do
      original = @dash.name
      visit dashboard_path(@dash.slug)
      title = find("[data-tiler-dashboard-title]", wait: 5)
      title.double_click
      page.execute_script(<<~JS)
        var el = document.querySelector("[data-tiler-dashboard-title]");
        el.textContent = "";
        el.dispatchEvent(new FocusEvent("blur"));
      JS
      sleep 0.3
      assert_equal original, @dash.reload.name
      assert_equal original, find("[data-tiler-dashboard-title]").text.strip
      assert_selector ".tiler-flash-alert", text: /empty/i, wait: 3
    end

    test "duplicate name surfaces server validation error and reverts" do
      other = create_dashboard(name: "Taken #{SecureRandom.hex(3)}")
      original = @dash.name
      visit dashboard_path(@dash.slug)
      title = find("[data-tiler-dashboard-title]", wait: 5)
      title.double_click
      page.execute_script(<<~JS)
        var el = document.querySelector("[data-tiler-dashboard-title]");
        el.textContent = #{other.name.to_json};
        el.dispatchEvent(new FocusEvent("blur"));
      JS
      assert_selector ".tiler-flash-alert", wait: 5
      assert_equal original, @dash.reload.name
    end
  end
end
