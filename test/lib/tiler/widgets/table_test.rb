require "test_helper"

# Table widget — structured columns + group_by per design catalog.
module Tiler
  class WidgetsTableTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash   = create_dashboard
      # Three endpoints, multiple records each.
      [ "/api/users", "/api/orders", "/api/search" ].each do |ep|
        3.times do
          create_record(@source, { "endpoint" => ep,
                                   "p50" => rand(20..120),
                                   "p95" => rand(140..680),
                                   "rpm" => rand(100..900) })
        end
      end
    end

    def panel(config)
      create_panel(@dash, widget_type: "table", data_source: @source,
                   config: config.to_json)
    end

    test "groups by group_by and returns one row per group" do
      data = panel(
        "group_by" => "endpoint",
        "columns"  => [
          { "label" => "p50", "column" => "p50", "num" => true, "agg" => "avg" },
          { "label" => "p95", "column" => "p95", "num" => true, "agg" => "avg" }
        ]
      ).data
      assert_equal 3, data[:rows].size
      groups = data[:rows].map(&:first)
      assert_equal %w[/api/orders /api/search /api/users].sort, groups.sort
    end

    test "first column is the group_by header followed by declared columns" do
      data = panel(
        "group_by" => "endpoint",
        "columns"  => [
          { "label" => "p95", "column" => "p95", "num" => true }
        ]
      ).data
      assert_equal "Endpoint", data[:columns][0][:label]
      assert_equal false,      data[:columns][0][:num]
      assert_equal "p95",      data[:columns][1][:label]
      assert_equal true,       data[:columns][1][:num]
    end

    test "sorts rows by first numeric column descending" do
      data = panel(
        "group_by" => "endpoint",
        "columns"  => [
          { "label" => "p95", "column" => "p95", "num" => true, "agg" => "max" }
        ]
      ).data
      values = data[:rows].map { |r| r[1].to_f }
      assert_equal values.sort.reverse, values, "rows should be sorted desc by first num column"
    end

    test "limit caps the number of rows" do
      data = panel(
        "group_by" => "endpoint",
        "limit"    => 2,
        "columns"  => [
          { "label" => "p50", "column" => "p50", "num" => true }
        ]
      ).data
      assert_equal 2, data[:rows].size
      assert_equal 3, data[:total]
    end

    test "missing group_by returns empty rows (renders empty state)" do
      data = panel(
        "columns" => [ { "label" => "p50", "column" => "p50", "num" => true } ]
      ).data
      assert_equal [], data[:rows]
    end

    test "missing columns returns empty rows" do
      data = panel("group_by" => "endpoint").data
      assert_equal [], data[:rows]
    end

    test "rejects unsafe column names in group_by and columns" do
      data = panel(
        "group_by" => "endpoint; DROP TABLE",
        "columns"  => [ { "label" => "p50", "column" => "p50", "num" => true } ]
      ).data
      assert_equal [], data[:rows]
      # Unsafe column inside columns array is filtered out, leaving 0 columns.
      data2 = panel(
        "group_by" => "endpoint",
        "columns"  => [ { "label" => "x", "column" => "p50; DROP" } ]
      ).data
      assert_equal [], data2[:rows]
    end
  end
end
