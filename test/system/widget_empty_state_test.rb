require "application_system_test_case"

# Empty-state coverage for data-backed widgets.
# A panel with no data should tell the user how to fix it (Edit) instead
# of rendering a blank canvas.
module Tiler
  class WidgetEmptyStateTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @empty_source = create_data_source
      @dash = create_dashboard(name: "Empty #{SecureRandom.hex(3)}")
    end

    test "bar chart with no data shows a configure message, not a blank canvas" do
      panel = create_panel(@dash, title: "Empty Bar", widget_type: "bar_chart",
                          data_source: @empty_source,
                          x: 0, y: 0, width: 6, height: 3,
                          config: { aggregation: "count" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector ".tiler-panel-empty", wait: 5
      assert_text "No data yet"
    end

    test "line chart with no data shows a configure message" do
      panel = create_panel(@dash, title: "Empty Line", widget_type: "line_chart",
                          data_source: @empty_source,
                          x: 0, y: 0, width: 6, height: 3,
                          config: { bucket: "1d", time_window: "7d",
                                    series: [ { label: "duration", column: "duration", agg: "avg" } ]
                                  }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector ".tiler-panel-empty", wait: 5
      assert_text "No data yet"
    end

    test "pie chart with no data shows a configure message" do
      panel = create_panel(@dash, title: "Empty Pie", widget_type: "pie_chart",
                          data_source: @empty_source,
                          x: 0, y: 0, width: 6, height: 3,
                          config: { aggregation: "count", group_column: "status" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector ".tiler-panel-empty", wait: 5
      assert_text "No data yet"
    end

    test "data-backed widget with no data_source shows a configure message" do
      panel = create_panel(@dash, title: "No source", widget_type: "metric",
                          data_source: nil,
                          x: 0, y: 0, width: 4, height: 2,
                          config: { aggregation: "count" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector ".tiler-panel-empty", wait: 5
      assert_text(/configure/i)
    end

    test "the empty-state has a Configure button that opens the slide-over drawer" do
      panel = create_panel(@dash, title: "Empty Bar 2", widget_type: "bar_chart",
                          data_source: @empty_source,
                          x: 0, y: 0, width: 6, height: 3,
                          config: { aggregation: "count" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      btn = find(".tiler-panel-empty button", text: /configure/i, wait: 5)
      assert_includes btn["data-tiler--drawer-url-param"],
                      "/panels/#{panel.id}/edit"
      assert_includes btn["data-action"], "tiler--drawer#openWith"
    end

    test "chart widget WITH data does not show the empty state" do
      source = create_data_source
      5.times { create_record(source, { status: "ok", duration: 100.0 }) }
      panel = create_panel(@dash, title: "Populated Bar", widget_type: "bar_chart",
                          data_source: source,
                          x: 0, y: 0, width: 6, height: 3,
                          config: { aggregation: "count", group_column: "status",
                                    value_column: "duration" }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
      assert_selector "canvas#tiler-chart-#{panel.id}", wait: 5
      assert_no_selector "turbo-frame#tiler_panel_#{panel.id} .tiler-panel-empty"
    end
  end
end
