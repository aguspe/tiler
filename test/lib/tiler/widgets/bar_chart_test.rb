require "test_helper"

# Bar chart — single dataset whose bars use the full viz palette in order.
module Tiler
  class WidgetsBarChartTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash   = create_dashboard
    end

    def panel(config)
      create_panel(@dash, widget_type: "bar_chart", data_source: @source,
                   config: config.to_json)
    end

    test "single dataset; one bar per group from group_column" do
      %w[api web worker].each_with_index do |svc, i|
        (i + 1).times { create_record(@source, { service: svc, count: 1 }) }
      end
      data = panel(
        "group_column" => "service",
        "value_column" => "count",
        "aggregation"  => "sum"
      ).data
      assert_equal 1, data[:datasets].size
      assert_equal 3, data[:labels].size
    end

    test "each bar gets a palette color in registration order" do
      %w[a b c d].each { |g| create_record(@source, { service: g, count: 1 }) }
      data = panel(
        "group_column" => "service",
        "value_column" => "count",
        "aggregation"  => "sum"
      ).data
      borders = data[:datasets][0][:borderColor]
      assert_kind_of Array, borders, "borderColor must be per-bar (array)"
      assert_equal "#3b82f6", borders[0]
      assert_equal "#10b981", borders[1]
      assert_equal "#f59e0b", borders[2]
      assert_equal "#ef4444", borders[3]
    end

    test "limit caps the number of bars" do
      15.times { |i| create_record(@source, { service: "s#{i}", count: 1 }) }
      data = panel(
        "group_column" => "service",
        "value_column" => "count",
        "aggregation"  => "sum",
        "limit"        => 5
      ).data
      assert_equal 5, data[:labels].size
      assert_equal 5, data[:datasets][0][:data].size
    end

    test "missing group_column returns empty result" do
      data = panel("value_column" => "count").data
      assert_equal [], data[:labels]
      assert_equal [], data[:datasets]
    end
  end
end
