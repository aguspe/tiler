require "test_helper"

module Tiler
  class QueryTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash = create_dashboard
      3.times { create_record(@source, { status: "ok",  duration: 100.0 }) }
      2.times { create_record(@source, { status: "err", duration: 500.0 }) }
    end

    def panel_with(widget_type, config = {})
      create_panel(@dash, widget_type: widget_type, data_source: @source, config: config.to_json)
    end

    test "metric count" do
      data = panel_with("metric", { aggregation: "count" }).data
      assert_equal 5, data[:value]
    end

    test "metric avg" do
      data = panel_with("metric", { aggregation: "avg", value_column: "duration" }).data
      assert_equal 260.0, data[:value]
    end

    test "metric sum" do
      data = panel_with("metric", { aggregation: "sum", value_column: "duration" }).data
      assert_equal 1300.0, data[:value]
    end

    test "metric min/max" do
      assert_equal 100.0, panel_with("metric", { aggregation: "min", value_column: "duration" }).data[:value]
      assert_equal 500.0, panel_with("metric", { aggregation: "max", value_column: "duration" }).data[:value]
    end

    test "table returns rows limited" do
      data = panel_with("table", { limit: 3 }).data
      assert_equal 3, data[:rows].size
      assert_equal 5, data[:total]
    end

    test "pie groups by column" do
      data = panel_with("pie_chart", { group_by: "status", aggregation: "count" }).data
      labels = data[:labels]
      assert_includes labels, "ok"
      assert_includes labels, "err"
    end

    test "list ranks top items" do
      data = panel_with("list", { group_by: "status", aggregation: "count", limit: 10 }).data
      labels = data[:items].map { |i| i[:label] }
      values = data[:items].map { |i| i[:value] }
      assert_equal "ok", labels.first
      assert_equal 3, values.first
    end

    test "unsafe column names are rejected" do
      panel = panel_with("metric", { aggregation: "sum", value_column: "x; DROP TABLE" })
      assert_raises(ArgumentError) { panel.data }
    end

    test "time_window filter applies" do
      @source.data_records.update_all(recorded_at: 30.days.ago)
      create_record(@source, { status: "ok", duration: 1.0 }, recorded_at: 1.hour.ago)
      data = panel_with("metric", { aggregation: "count", time_window: "24h" }).data
      assert_equal 1, data[:value]
    end

    test "filter by payload value" do
      data = panel_with("metric",
        { aggregation: "count", filter: { "status" => "ok" } }).data
      assert_equal 3, data[:value]
    end

    test "clock widget returns timezone config" do
      panel = create_panel(@dash, widget_type: "clock", config: { format: "12h" }.to_json)
      assert_equal "12h", panel.data[:format]
    end

    test "text widget returns text from config" do
      panel = create_panel(@dash, widget_type: "text", config: { text: "hello" }.to_json)
      assert_equal "hello", panel.data[:text]
    end

    test "iframe widget returns url from config" do
      panel = create_panel(@dash, widget_type: "iframe", config: { url: "https://example.com" }.to_json)
      assert_equal "https://example.com", panel.data[:url]
    end

    test "number_with_delta computes delta" do
      now = Time.current
      panel = create_panel(@dash, widget_type: "number_with_delta", data_source: @source,
                           config: { aggregation: "count",
                                     time_window: "24h",
                                     previous_window: "24h" }.to_json)
      @source.data_records.delete_all
      3.times { create_record(@source, { status: "ok" }, recorded_at: 2.hours.ago) }
      2.times { create_record(@source, { status: "ok" }, recorded_at: 30.hours.ago) }
      data = panel.data
      assert_equal 3, data[:value]
      assert_equal 2, data[:previous]
      assert_equal :up, data[:direction]
    end
  end
end
