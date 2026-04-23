require "test_helper"

# Line chart — structured `series` + `1h/1d/1w` bucket strings per catalog.
module Tiler
  class WidgetsLineChartTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash   = create_dashboard
      # Distribute records across the last 5 days so 1d buckets are populated.
      5.times do |i|
        2.times { create_record(@source, { rpm: 100 + i, errors: i },
                                recorded_at: i.days.ago) }
      end
    end

    def panel(config)
      create_panel(@dash, widget_type: "line_chart", data_source: @source,
                   config: config.to_json)
    end

    test "one dataset per series entry, label honored" do
      data = panel(
        "time_window" => "7d",
        "bucket"      => "1d",
        "series" => [
          { "label" => "Requests", "column" => "rpm",    "agg" => "sum" },
          { "label" => "Errors",   "column" => "errors", "agg" => "sum" }
        ]
      ).data
      assert_equal 2, data[:datasets].size
      assert_equal "Requests", data[:datasets][0][:label]
      assert_equal "Errors",   data[:datasets][1][:label]
    end

    test "palette colors are assigned in registration order" do
      data = panel(
        "time_window" => "7d",
        "bucket"      => "1d",
        "series" => [
          { "label" => "A", "column" => "rpm",    "agg" => "sum" },
          { "label" => "B", "column" => "errors", "agg" => "sum" }
        ]
      ).data
      assert_equal "#3b82f6", data[:datasets][0][:borderColor]
      assert_equal "#10b981", data[:datasets][1][:borderColor]
    end

    test "1h bucket uses hour-aligned slots" do
      data = panel(
        "time_window" => "24h",
        "bucket"      => "1h",
        "series" => [ { "label" => "rpm", "column" => "rpm", "agg" => "sum" } ]
      ).data
      assert_includes [ 24, 25 ], data[:labels].size,
                      "expected ~24 hourly buckets for 24h window (got #{data[:labels].size})"
    end

    test "1w bucket label is week-prefixed" do
      data = panel(
        "time_window" => "30d",
        "bucket"      => "1w",
        "series" => [ { "label" => "rpm", "column" => "rpm", "agg" => "sum" } ]
      ).data
      assert data[:labels].first.start_with?("W"), "expected week label prefix (got #{data[:labels].first.inspect})"
    end

    test "invalid bucket falls back to 1d" do
      data = panel(
        "time_window" => "7d",
        "bucket"      => "month",
        "series" => [ { "label" => "rpm", "column" => "rpm", "agg" => "sum" } ]
      ).data
      assert_includes [ 7, 8 ], data[:labels].size,
                      "invalid bucket should fall back to 1d (got #{data[:labels].size} labels)"
    end

    test "missing series returns empty datasets" do
      data = panel("time_window" => "7d").data
      assert_equal [], data[:datasets]
    end

    test "rejects unsafe column names in series" do
      data = panel(
        "time_window" => "7d",
        "bucket"      => "1d",
        "series" => [ { "label" => "x", "column" => "rpm; DROP" } ]
      ).data
      assert_equal [], data[:datasets]
    end
  end
end
