require "application_system_test_case"

# Coverage for:
#  1. Every data-backed widget falls back to the global "configure" empty
#     state when no data source is attached (not the inline "No records." /
#     "No items." text).
#  2. Pasting `{"_preview": {...}}` into Config renders the widget with that
#     static data — no data source needed.
#  3. The "How do I push data" info section links to Data Sources.
#  4. The Data Sources index page carries an About header.
module Tiler
  class WidgetPreviewAndDataSourcesTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Preview #{SecureRandom.hex(3)}")
    end

    test "table widget without data_source shows the global empty state" do
      panel = create_panel(@dash, title: "Empty table", widget_type: "table",
                           data_source: nil,
                           x: 0, y: 0, width: 6, height: 3,
                           config: {}.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector ".tiler-panel-empty", wait: 5
      assert_no_text "No records."
    end

    test "list widget without data_source shows the global empty state" do
      panel = create_panel(@dash, title: "Empty list", widget_type: "list",
                           data_source: nil,
                           x: 0, y: 0, width: 4, height: 3,
                           config: {}.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector ".tiler-panel-empty", wait: 5
    end

    test "table widget with _preview config renders the static data" do
      preview = {
        "_preview" => {
          "rows"    => [ [ "ok", 142.3 ], [ "err", 88.0 ] ],
          "columns" => %w[status duration],
          "total"   => 2
        }
      }
      panel = create_panel(@dash, title: "Preview table", widget_type: "table",
                           data_source: nil,
                           x: 0, y: 0, width: 6, height: 3,
                           config: preview.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      within("turbo-frame#tiler_panel_#{panel.id}") do
        assert_selector "table.tiler-table", wait: 5
        assert_text "ok"
        assert_text "142.3"
      end
    end

    test "metric widget with _preview config renders the static value" do
      preview = { "_preview" => { "value" => 99, "label" => "Static" } }
      panel = create_panel(@dash, title: "Preview metric", widget_type: "metric",
                           data_source: nil,
                           x: 0, y: 0, width: 3, height: 2,
                           config: preview.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      within("turbo-frame#tiler_panel_#{panel.id}") do
        assert_text "99"
        assert_text "Static"
      end
    end

    test "How-do-I-push-data hint includes a clickable link to Data Sources" do
      panel = create_panel(@dash, title: "Linked help", widget_type: "metric",
                           data_source: nil,
                           x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      within("[data-tiler-info]") do
        link = find("a", text: /data sources/i, wait: 5)
        assert_includes link["href"], data_sources_path
      end
    end

    test "Data Sources index has an About header" do
      visit data_sources_path
      assert_selector "[data-tiler-about-data-sources]", wait: 5
      assert_text(/data source/i)
    end
  end
end
