require "application_system_test_case"

# Coverage for the panel-edit help features:
#  - Update / Delete buttons share a row (Update left, Delete right)
#  - Each panel shows a copy-paste JSON example for its widget config
#  - Info disclosure shows the webhook endpoint + sample payload + curl
module Tiler
  class PanelEditHelpTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      @dash = create_dashboard(name: "Edit Help #{SecureRandom.hex(3)}")
      @panel = create_panel(@dash, title: "Help me", widget_type: "metric",
                            data_source: @source,
                            x: 0, y: 0, width: 4, height: 2,
                            config: { aggregation: "count" }.to_json)
    end

    test "edit page has Update on the left and Delete on the right in one row" do
      visit edit_dashboard_panel_path(@dash, @panel)
      assert_selector ".tiler-form-actions", wait: 5

      update = find(".tiler-form-actions button[type='submit']", text: /update/i, wait: 5)
      delete = find(".tiler-form-actions button", text: /delete/i, wait: 5)
      # Update appears earlier in the DOM than Delete.
      assert update.path < delete.path,
             "Update (#{update.path}) should appear before Delete (#{delete.path}) in DOM"
    end

    test "edit page shows a copy-paste JSON example matching the widget type" do
      visit edit_dashboard_panel_path(@dash, @panel)
      assert_selector "[data-tiler-example-config]", wait: 5
      example = find("[data-tiler-example-config]", wait: 5)
      json = JSON.parse(example.text)
      # Metric example must include aggregation (the most basic field).
      assert json.key?("aggregation"), "metric example should suggest an 'aggregation' key; got #{example.text}"
    end

    test "edit page shows the webhook URL + sample payload + curl when a data source is attached" do
      visit edit_dashboard_panel_path(@dash, @panel)
      assert_selector "[data-tiler-info][open]", wait: 5
      within("[data-tiler-info]") do
        assert_text "/tiler/ingest/#{@source.slug}", wait: 5
        assert_text "X-Tiler-Token", wait: 5
        assert_text(/curl/i, wait: 5)
      end
    end

    test "info section is hidden (or shows a hint) when the panel has no data source" do
      panel_no_src = create_panel(@dash, title: "No source", widget_type: "clock",
                                  data_source: nil,
                                  x: 0, y: 4, width: 3, height: 2, config: {}.to_json)
      visit edit_dashboard_panel_path(@dash, panel_no_src)
      assert_selector "[data-tiler-info][open]", wait: 5
      within("[data-tiler-info]") do
        assert_text(/no data source/i, wait: 5)
      end
    end

    test "flash notice has a close button and auto-dismisses" do
      visit edit_dashboard_panel_path(@dash, @panel)
      fill_in "Title", with: "Updated title via test"
      click_button "Update Panel"
      # After redirect to dashboard show, flash notice "Panel updated." appears.
      assert_text "Panel updated", wait: 5
      assert_selector ".tiler-flash [data-tiler-flash-close]", wait: 5
      # Click the close button → flash gone.
      find(".tiler-flash [data-tiler-flash-close]").click
      assert_no_selector ".tiler-flash", wait: 2
    end

    test "flash auto-dismisses after timeout" do
      visit edit_dashboard_panel_path(@dash, @panel)
      fill_in "Title", with: "Auto dismiss test"
      click_button "Update Panel"
      assert_selector ".tiler-flash", wait: 5
      # Flash controller dismisses after configured timeout. Default is 5s; we
      # don't want the test to actually wait 5s, so bump down via JS.
      page.execute_script(<<~JS)
        document.querySelectorAll('[data-controller~="tiler--flash"]').forEach(function(el) {
          var ctrl = window.Stimulus.getControllerForElementAndIdentifier(el, 'tiler--flash');
          if (ctrl) ctrl.timeoutValue = 200;
        });
      JS
      assert_no_selector ".tiler-flash", wait: 2
    end

    test "switching widget type swaps the example config (server-rendered per widget)" do
      visit edit_dashboard_panel_path(@dash, @panel)
      example_metric = find("[data-tiler-example-config]").text
      # We don't trigger client-side swap; instead verify each widget partial would
      # render its own example. Visit the new-panel page with widget_type=line_chart.
      visit new_dashboard_panel_path(@dash, panel: { widget_type: "line_chart" })
      example_line = find("[data-tiler-example-config]", wait: 5).text
      refute_equal example_metric, example_line,
                   "different widgets should advertise different config examples"
    end
  end
end
