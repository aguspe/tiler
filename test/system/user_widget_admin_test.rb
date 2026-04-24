require "application_system_test_case"

# Phase B end-to-end: a non-engineer creates a custom widget through
# Settings → Custom widgets and immediately sees it appear in the Add Panel
# palette on a dashboard.
module Tiler
  class UserWidgetAdminTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      Tiler::UserWidget.delete_all
      @dash = create_dashboard(name: "Custom #{SecureRandom.hex(3)}")
      # Need at least one panel for the palette UI to render.
      create_panel(@dash, title: "Seed", widget_type: "clock",
                   x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
    end

    test "Settings page links to the custom widgets manager" do
      visit settings_path
      assert_selector "a", text: /custom widgets/i, wait: 5
    end

    test "creating a custom widget makes it show up in the dashboard palette" do
      visit user_widgets_path
      click_on "New custom widget"
      fill_in "Slug",  with: "smoke_test"
      fill_in "Label", with: "Smoke Test"
      # Default template seed is fine; just submit.
      click_on "Create widget"
      assert_text(/created/i)

      # Now the registry should expose user_smoke_test and the dashboard
      # palette renders it as a draggable item.
      assert_includes Tiler.widgets.types, "user_smoke_test"
      visit dashboard_path(@dash.slug)
      # Open the palette by toggling Add Panel.
      find("[data-tiler-add-panel]", wait: 5).click
      within("[data-tiler-palette]") do
        assert_text "Smoke Test"
      end
    end

    test "deleting a custom widget removes it from the registry + the index" do
      Tiler::UserWidget.create!(slug: "doomed", label: "Doomed",
                                template: "x", data_kind: "config_only")
      assert_includes Tiler.widgets.types, "user_doomed"
      visit user_widgets_path
      assert_text "doomed", wait: 5
      page.execute_script(<<~JS)
        document.querySelector("[data-tiler-user-widget-row='doomed'] [data-tiler-user-widget-delete]").click();
      JS
      find("[data-tiler-modal-confirm]", wait: 5).click
      Timeout.timeout(5) { sleep 0.05 until !Tiler::UserWidget.exists?(slug: "doomed") }
      refute_includes Tiler.widgets.types, "user_doomed"
    end
  end
end
