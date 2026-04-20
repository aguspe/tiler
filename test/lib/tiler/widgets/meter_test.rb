require "test_helper"

module Tiler
  module Widgets
    class MeterTest < ActionView::TestCase
      setup do
        @source = create_data_source
        @dash   = create_dashboard
        # Seed records spanning recorded_at; "last" should pick the most recent.
        create_record(@source, { value: 100.0 }, recorded_at: 5.hours.ago)
        create_record(@source, { value: 200.0 }, recorded_at: 4.hours.ago)
        create_record(@source, { value: 300.0 }, recorded_at: 3.hours.ago)
        create_record(@source, { value: 400.0 }, recorded_at: 2.hours.ago)
        create_record(@source, { value: 500.0 }, recorded_at: 1.hour.ago)
      end

      def panel_with(config = {})
        create_panel(@dash, widget_type: "meter", data_source: @source, config: config.to_json)
      end

      def render_partial(panel)
        render partial: "tiler/widgets/meter", locals: { panel: panel, data: panel.data }
      end

      test "registry returns the registered class with documented attributes" do
        klass = Tiler.widgets["meter"]
        assert_equal Tiler::Widgets::Meter, klass
        assert_equal "meter", klass.type
        assert_equal "Meter", klass.label
        assert_equal "tiler/widgets/meter", klass.partial
        assert_equal Tiler::Widgets::MeterQuery, klass.query_class
      end

      test "query returns exactly five keys" do
        data = panel_with(value_column: "value", aggregation: "last", max: 1000).data
        assert_equal %i[value min max prefix suffix].sort, data.keys.sort
      end

      test "min defaults to 0 and follows config when set" do
        d1 = panel_with(value_column: "value", aggregation: "last", max: 1000).data
        assert_equal 0.0, d1[:min]
        d2 = panel_with(value_column: "value", aggregation: "last", min: 50, max: 1000).data
        assert_equal 50.0, d2[:min]
      end

      test "max equals configured value" do
        data = panel_with(value_column: "value", aggregation: "last", max: 750).data
        assert_equal 750.0, data[:max]
      end

      test "aggregation last returns most recent recorded_at value" do
        data = panel_with(value_column: "value", aggregation: "last", max: 1000).data
        assert_equal 500.0, data[:value]
      end

      test "aggregation avg" do
        data = panel_with(value_column: "value", aggregation: "avg", max: 1000).data
        assert_equal 300.0, data[:value]
      end

      test "aggregation sum" do
        data = panel_with(value_column: "value", aggregation: "sum", max: 2000).data
        assert_equal 1500.0, data[:value]
      end

      test "aggregation min" do
        data = panel_with(value_column: "value", aggregation: "min", max: 1000).data
        assert_equal 100.0, data[:value]
      end

      test "aggregation max" do
        data = panel_with(value_column: "value", aggregation: "max", max: 1000).data
        assert_equal 500.0, data[:value]
      end

      test "below-min values clamp to min" do
        data = panel_with(value_column: "value", aggregation: "last", min: 600, max: 1000).data
        assert_equal 600.0, data[:value]
      end

      test "above-max values clamp to max" do
        data = panel_with(value_column: "value", aggregation: "last", min: 0, max: 400).data
        assert_equal 400.0, data[:value]
      end

      test "in-range values pass through" do
        data = panel_with(value_column: "value", aggregation: "last", min: 0, max: 1000).data
        assert_equal 500.0, data[:value]
      end

      test "empty data source returns five-key hash without raising" do
        empty = create_data_source
        empty_dash = create_dashboard
        panel = create_panel(empty_dash, widget_type: "meter", data_source: empty,
                             config: { value_column: "value", aggregation: "last", max: 100 }.to_json)
        data = panel.data
        assert_equal %i[value min max prefix suffix].sort, data.keys.sort
        assert_nil data[:value]
      end

      test "partial renders SVG element" do
        panel = panel_with(value_column: "value", aggregation: "last", max: 1000)
        html = render_partial(panel)
        assert_equal 1, html.scan(/<svg\b/).size
      end

      test "blank prefix and suffix emit nothing extra around value" do
        panel = panel_with(value_column: "value", aggregation: "last", max: 1000)
        html = render_partial(panel)
        text_node = html[/<text[^>]*>([^<]*)<\/text>/, 1]
        assert_equal "500", text_node
      end

      test "prefix and suffix render adjacent in text node" do
        panel = panel_with(value_column: "value", aggregation: "last", max: 1000,
                           prefix: "$", suffix: " ms")
        html = render_partial(panel)
        text_node = html[/<text[^>]*>([^<]*)<\/text>/, 1]
        assert_equal "$500 ms", text_node
      end

      test "unknown aggregation falls back to last" do
        data = panel_with(value_column: "value", aggregation: "drop_table", max: 1000).data
        # last value is 500 in the fixture
        assert_equal 500.0, data[:value]
      end

      test "blank aggregation falls back to last" do
        data = panel_with(value_column: "value", aggregation: "", max: 1000).data
        assert_equal 500.0, data[:value]
      end

      test "nil aggregation falls back to last" do
        panel = create_panel(@dash, widget_type: "meter", data_source: @source,
                             config: { value_column: "value", max: 1000 }.to_json)
        assert_equal 500.0, panel.data[:value]
      end

      test "missing max renders configuration placeholder, not gauge" do
        panel = create_panel(@dash, widget_type: "meter", data_source: @source,
                             config: { value_column: "value", aggregation: "last" }.to_json)
        data = panel.data
        assert_nil data[:max]
        html = render_partial(panel)
        assert_match(/Configure a numeric/i, html)
        assert_equal 0, html.scan(/<svg\b/).size
      end

      test "value at min and value at max produce divergent SVG markup" do
        # Value at min: clamp to 0, foreground arc omitted.
        at_min = panel_with(value_column: "value", aggregation: "min", min: 100, max: 1000).data
        # Value at max: clamp to 1000.
        at_max_panel = panel_with(value_column: "value", aggregation: "last", min: 0, max: 500)
        at_max = at_max_panel.data
        assert_equal 100.0, at_min[:value]
        assert_equal 500.0, at_max[:value]

        min_panel = panel_with(value_column: "value", aggregation: "min", min: 100, max: 1000)
        max_panel = at_max_panel
        min_html = render_partial(min_panel)
        max_html = render_partial(max_panel)
        refute_equal min_html, max_html
        # Min case: only the background path. Max case: background + foreground.
        assert min_html.scan(/<path\b/).size < max_html.scan(/<path\b/).size
      end

      test "nil value renders without raising" do
        empty = create_data_source
        empty_dash = create_dashboard
        panel = create_panel(empty_dash, widget_type: "meter", data_source: empty,
                             config: { value_column: "value", aggregation: "last", max: 100 }.to_json)
        assert_nothing_raised { render_partial(panel) }
      end

      test "registry enumeration includes meter" do
        assert_includes Tiler.widgets.types, "meter"
        assert Tiler.widgets.options_for_select.any? { |label, type| type == "meter" && label == "Meter" }
      end
    end
  end
end
