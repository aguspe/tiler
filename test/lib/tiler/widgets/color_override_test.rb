require "test_helper"

# Per-panel color/palette override — every widget that opts in via
# `supports_color_config?` reads `config.color` (single hex) and/or
# `config.palette` (array) and applies them ahead of the default chart
# palette. Widgets that don't opt in must ignore both keys.
module Tiler
  class WidgetsColorOverrideTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash   = create_dashboard
    end

    def panel(type, config_hash = {})
      create_panel(@dash, widget_type: type, data_source: @source,
                   config: config_hash.to_json)
    end

    OPT_IN  = %w[meter number_with_delta bar_chart pie_chart line_chart].freeze
    OPT_OUT = %w[clock text iframe image list table comments status_grid metric].freeze

    OPT_IN.each do |type|
      define_method "test_#{type}_supports_color_config" do
        assert Tiler.widgets[type].supports_color_config?,
               "#{type} should opt into color config"
      end
    end

    OPT_OUT.each do |type|
      define_method "test_#{type}_does_not_support_color_config" do
        refute Tiler.widgets[type].supports_color_config?,
               "#{type} should NOT opt into color config"
      end
    end

    %w[bar_chart pie_chart line_chart].each do |type|
      define_method "test_#{type}_supports_palette_config" do
        assert Tiler.widgets[type].supports_palette_config?
      end
    end

    test "bar_chart respects palette override (per-bar colors come from config)" do
      %w[a b c].each { |g| create_record(@source, { service: g, count: 1 }) }
      data = panel("bar_chart", {
        "group_column" => "service", "value_column" => "count",
        "aggregation"  => "sum",
        "palette"      => [ "#111111", "#222222", "#333333" ]
      }).data
      borders = data[:datasets][0][:borderColor]
      assert_equal [ "#111111", "#222222", "#333333" ], borders
    end

    test "pie_chart palette override beats the default chart_colors" do
      %w[a b].each { |g| create_record(@source, { status: g }) }
      data = panel("pie_chart", {
        "group_column" => "status",
        "palette"      => [ "#abcdef", "#fedcba" ]
      }).data
      borders = data[:datasets][0][:borderColor]
      assert_equal "#abcdef", borders[0]
      assert_equal "#fedcba", borders[1]
    end

    test "line_chart per-series color wins over palette and default" do
      5.times do |i|
        create_record(@source, { rpm: 100 + i, errors: i }, recorded_at: i.days.ago)
      end
      data = panel("line_chart", {
        "time_window" => "7d", "bucket" => "1d",
        "series" => [
          { "label" => "A", "column" => "rpm",    "agg" => "sum", "color" => "#cc00cc" },
          { "label" => "B", "column" => "errors", "agg" => "sum" }
        ],
        "palette" => [ "#111111", "#222222" ]
      }).data
      # Series 0 pins its own color; series 1 falls through to palette[1].
      assert_equal "#cc00cc", data[:datasets][0][:borderColor]
      assert_equal "#222222", data[:datasets][1][:borderColor]
    end

    test "line_chart palette override colors series in order" do
      5.times do |i|
        create_record(@source, { rpm: 100 + i, errors: i }, recorded_at: i.days.ago)
      end
      data = panel("line_chart", {
        "time_window" => "7d", "bucket" => "1d",
        "series" => [
          { "label" => "A", "column" => "rpm",    "agg" => "sum" },
          { "label" => "B", "column" => "errors", "agg" => "sum" }
        ],
        "palette" => [ "#aaa111", "#bbb222" ]
      }).data
      assert_equal "#aaa111", data[:datasets][0][:borderColor]
      assert_equal "#bbb222", data[:datasets][1][:borderColor]
    end

    test "single color override broadcasts to a 1-entry palette for charts" do
      %w[a b].each { |g| create_record(@source, { status: g }) }
      data = panel("pie_chart", {
        "group_column" => "status",
        "color"        => "#deadbe"
      }).data
      assert_includes data[:datasets][0][:borderColor], "#deadbe"
    end

    test "invalid hex in palette is dropped silently (sanitization)" do
      %w[a b c].each { |g| create_record(@source, { service: g, count: 1 }) }
      data = panel("bar_chart", {
        "group_column" => "service", "value_column" => "count",
        "palette"      => [ "#111", "javascript:alert(1)", "#222" ]
      }).data
      borders = data[:datasets][0][:borderColor]
      # Only valid hex survives; default palette fills the gap for the third bar.
      assert_equal "#111", borders[0]
      assert_equal "#222", borders[1]
    end

    test "meter exposes color in data hash; nil when not configured" do
      create_record(@source, { value: 50 })
      with    = panel("meter", { "value_column" => "value", "max" => 100, "color" => "#abcdef" }).data
      without = panel("meter", { "value_column" => "value", "max" => 100 }).data
      assert_equal "#abcdef", with[:color]
      assert_nil without[:color]
    end

    test "number_with_delta exposes color in data hash" do
      create_record(@source, { duration: 100 })
      data = panel("number_with_delta", {
        "value_column" => "duration", "aggregation" => "avg",
        "time_window"  => "24h", "color" => "#cafe00"
      }).data
      assert_equal "#cafe00", data[:color]
    end
  end
end
