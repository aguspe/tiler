require "test_helper"

# number_with_delta — value, delta, AND inline sparkline per catalog spec.
module Tiler
  class WidgetsNumberWithDeltaTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      @dash   = create_dashboard
      # 7 records spread across the last day so spark buckets are populated.
      7.times do |i|
        create_record(@source, { duration: 100 + i * 10 },
                      recorded_at: i.hours.ago)
      end
    end

    def panel(extra = {})
      base = { value_column: "duration", aggregation: "avg",
               time_window: "24h", delta_window: "24h" }
      create_panel(@dash, widget_type: "number_with_delta",
                   data_source: @source, config: base.merge(extra).to_json)
    end

    test "returns a 7-point sparkline by default" do
      data = panel.data
      assert_kind_of Array, data[:spark]
      assert_equal 7, data[:spark].size
      data[:spark].each { |v| assert_kind_of Numeric, v }
    end

    test "spark: false suppresses the sparkline" do
      data = panel(spark: false).data
      assert_nil data[:spark]
    end

    test "sparkline is nil when there is no data source" do
      panel = create_panel(@dash, widget_type: "number_with_delta",
                           data_source: nil,
                           config: { aggregation: "count", time_window: "24h" }.to_json)
      assert_nil panel.data[:spark]
    end

    test "sparkline returns nil when all buckets are zero (suppress flat line)" do
      empty = create_data_source(name: "empty-#{SecureRandom.hex(3)}")
      panel = create_panel(@dash, widget_type: "number_with_delta",
                           data_source: empty,
                           config: { value_column: "duration", aggregation: "avg",
                                     time_window: "24h" }.to_json)
      assert_nil panel.data[:spark]
    end
  end
end
