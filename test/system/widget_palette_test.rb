require "application_system_test_case"

module Tiler
  class WidgetPaletteTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      3.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard(name: "Palette UI Test")
      # Need at least one panel so the dashboard show renders the .grid-stack branch (palette lives next to it).
      create_panel(@dash, title: "Seed", widget_type: "clock",
                   x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
    end

    test "palette is hidden by default and visible in edit mode" do
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-palette]", visible: :hidden, wait: 5
      click_button "Add Panel"
      assert_selector "[data-tiler-palette]", visible: true, wait: 5
      click_button "Close Palette"
      assert_selector "[data-tiler-palette]", visible: :hidden, wait: 5
    end

    test "palette renders one item per registered widget type" do
      visit dashboard_path(@dash.slug)
      click_button "Add Panel"
      assert_selector "[data-tiler-palette-widget]", count: Tiler.widgets.types.size, wait: 5
      Tiler.widgets.types.each do |type|
        assert_selector "[data-tiler-palette-widget][data-widget-type='#{type}']", wait: 5
      end
    end

    test "each palette item has the widget label and default config attributes" do
      visit dashboard_path(@dash.slug)
      click_button "Add Panel"
      Tiler.widgets.each do |type, klass|
        item = find("[data-tiler-palette-widget][data-widget-type='#{type}']")
        assert_includes item.text, klass.label
        assert item["data-default-w"].present?, "#{type} missing data-default-w"
        assert item["data-default-h"].present?, "#{type} missing data-default-h"
        assert item["data-default-config"].present?, "#{type} missing data-default-config"
      end
    end

    test "palette items are keyboard reachable" do
      visit dashboard_path(@dash.slug)
      click_button "Add Panel"
      first_item = first("[data-tiler-palette-widget]")
      assert first_item["tabindex"], "palette item should have tabindex"
      assert_equal "0", first_item["tabindex"]
    end
  end
end
