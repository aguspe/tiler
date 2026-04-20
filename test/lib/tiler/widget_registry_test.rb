require "test_helper"

module Tiler
  class WidgetRegistryTest < ActiveSupport::TestCase
    test "builtin widgets are registered" do
      %w[metric table line_chart bar_chart pie_chart status_grid
         clock text iframe list number_with_delta].each do |t|
        assert Tiler.widgets[t], "Expected #{t} to be registered"
      end
    end

    test "fetch raises for unknown widget" do
      assert_raises(Tiler::Error) { Tiler.widgets.fetch("nope") }
    end

    test "options_for_select returns [label, type] pairs" do
      opts = Tiler.widgets.options_for_select
      assert opts.any? { |label, type| type == "metric" && label == "Single Metric" }
    end

    test "can register a new widget klass" do
      klass = Class.new(Tiler::Widget) do
        self.type = "custom_x"
        self.label = "Custom X"
        self.partial = "tiler/widgets/custom_x"
      end
      Tiler.widgets.register("custom_x", klass: klass)
      assert_equal klass, Tiler.widgets["custom_x"]
    ensure
      Tiler.widgets.instance_variable_get(:@widgets).delete("custom_x")
    end
  end
end
