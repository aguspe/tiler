require "test_helper"

# Pie chart — limit with "Other" overflow bucket; legend right at >=4 cols.
module Tiler
  class WidgetsPieChartTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash   = create_dashboard
    end

    def panel(config_hash = {}, width: 6)
      create_panel(@dash, widget_type: "pie_chart", data_source: @source,
                   width: width, height: 3, config: config_hash.to_json)
    end

    test "no limit overflow → no Other slice" do
      %w[a b c].each_with_index do |g, i|
        (i + 1).times { create_record(@source, { status: g }) }
      end
      data = panel({ "group_column" => "status", "limit" => 6 }).data
      assert_equal 3, data[:labels].size
      refute_includes data[:labels], "Other"
    end

    test "more groups than limit → overflow collapses into a single Other slice" do
      10.times { |i| (i + 1).times { create_record(@source, { status: "g#{i}" }) } }
      data = panel({ "group_column" => "status", "limit" => 4 }).data
      assert_equal 5, data[:labels].size, "expected 4 top + 1 Other (got #{data[:labels].inspect})"
      assert_equal "Other", data[:labels].last
      kept_total  = data[:datasets][0][:data][0..3].sum
      other_value = data[:datasets][0][:data].last
      total       = (1..10).sum
      assert_equal total, kept_total + other_value
    end

    test "kept slices are the largest by value (descending sort)" do
      [ [ "small", 1 ], [ "huge", 50 ], [ "medium", 10 ] ].each do |g, count|
        count.times { create_record(@source, { status: g }) }
      end
      data = panel({ "group_column" => "status", "limit" => 2 }).data
      # Top 2 are huge + medium; small collapses into Other.
      assert_equal %w[huge medium Other], data[:labels]
    end

    test "Other slice is omitted when overflow values sum to zero" do
      %w[a b].each { |g| 2.times { create_record(@source, { status: g }) } }
      # value_column "missing" makes leftover groups aggregate to 0.
      data = panel({ "group_column" => "status", "limit" => 1,
                     "value_column" => "missing", "aggregation" => "sum" }).data
      refute_includes data[:labels], "Other"
    end

    test "legend defaults to top at narrow widths (<4 cols)" do
      %w[a b].each { |g| create_record(@source, { status: g }) }
      data = panel({ "group_column" => "status" }, width: 3).data
      assert_equal "top", data.dig(:options, :plugins, :legend, :position)
    end

    test "legend moves to right at panel widths >= 4 cols" do
      %w[a b].each { |g| create_record(@source, { status: g }) }
      data = panel({ "group_column" => "status" }, width: 4).data
      assert_equal "right", data.dig(:options, :plugins, :legend, :position)
    end

    test "default limit (6) caps slices when none provided" do
      10.times { |i| create_record(@source, { status: "g#{i}" }) }
      data = panel({ "group_column" => "status" }).data
      # 6 kept + 1 Other = 7 labels
      assert_equal 7, data[:labels].size
      assert_equal "Other", data[:labels].last
    end
  end
end
