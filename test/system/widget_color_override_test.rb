require "application_system_test_case"

# Per-widget color override row on the edit drawer — visible only for
# widgets that opt in via Tiler::Widget.supports_color_config?
module Tiler
  class WidgetColorOverrideSystemTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Color #{SecureRandom.hex(3)}")
    end

    test "chart widget edit page shows the single + palette color rows" do
      panel = create_panel(@dash, title: "Bars", widget_type: "bar_chart",
                           data_source: nil, x: 0, y: 0, width: 6, height: 3,
                           config: {}.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      assert_selector "[data-tiler-widget-color]",   wait: 5
      assert_selector "[data-tiler-widget-palette]", wait: 5
    end

    test "config-only widget (clock) does NOT show the color row" do
      panel = create_panel(@dash, title: "Clock", widget_type: "clock",
                           data_source: nil, x: 0, y: 0, width: 3, height: 2,
                           config: {}.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      assert_no_selector "[data-tiler-widget-color]"
      assert_no_selector "[data-tiler-widget-palette]"
    end

    test "metric widget shows neither color row (catalog spec — no override)" do
      panel = create_panel(@dash, title: "M", widget_type: "metric",
                           data_source: nil, x: 0, y: 0, width: 3, height: 2,
                           config: {}.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      assert_no_selector "[data-tiler-widget-color]"
    end

    test "single color picker writes config.color into the JSON textarea" do
      panel = create_panel(@dash, title: "Meter", widget_type: "meter",
                           data_source: nil, x: 0, y: 0, width: 4, height: 3,
                           config: { "value_column" => "v", "max" => 100 }.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      assert_selector "[data-tiler-widget-color]", wait: 5
      page.execute_script(<<~JS)
        var picker = document.querySelector("[data-tiler-widget-color]");
        picker.value = "#abcdef";
        picker.dispatchEvent(new Event("input", { bubbles: true }));
      JS
      json = page.evaluate_script(<<~JS)
        document.querySelector("textarea[name='panel[config]']").value
      JS
      cfg = JSON.parse(json)
      assert_equal "#abcdef", cfg["color"]
    end

    test "palette text input writes config.palette as an array" do
      panel = create_panel(@dash, title: "Pie", widget_type: "pie_chart",
                           data_source: nil, x: 0, y: 0, width: 6, height: 3,
                           config: { "group_column" => "status" }.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      assert_selector "[data-tiler-widget-palette]", wait: 5
      page.execute_script(<<~JS)
        var box = document.querySelector("[data-tiler-widget-palette]");
        box.value = "#111111, #222222, #333333";
        box.dispatchEvent(new Event("input", { bubbles: true }));
      JS
      json = page.evaluate_script(<<~JS)
        document.querySelector("textarea[name='panel[config]']").value
      JS
      cfg = JSON.parse(json)
      assert_equal [ "#111111", "#222222", "#333333" ], cfg["palette"]
    end

    test "Reset button removes color + palette from the config JSON" do
      panel = create_panel(@dash, title: "Pie", widget_type: "pie_chart",
                           data_source: nil, x: 0, y: 0, width: 6, height: 3,
                           config: { "group_column" => "s",
                                     "color" => "#abc", "palette" => [ "#111" ] }.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      find("[data-tiler-widget-color-clear]", wait: 5).click
      json = page.evaluate_script(<<~JS)
        document.querySelector("textarea[name='panel[config]']").value
      JS
      cfg = JSON.parse(json)
      refute cfg.key?("color"),   "color must be cleared"
      refute cfg.key?("palette"), "palette must be cleared"
    end
  end
end
