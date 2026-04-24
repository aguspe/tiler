require "test_helper"
require "tiler/test_helpers"

# Phase A — verifies that a host app can drop a Ruby file in app/widgets/**
# and Tiler picks it up on boot. The fixture lives at
# test/dummy/app/widgets/tiler/sample_custom_widget.rb.
module Tiler
  class HostWidgetExtensionTest < ActiveSupport::TestCase
    include Tiler::WidgetTestHelper

    setup do
      @dash = create_dashboard
    end

    test "host app's widget is auto-registered after the engine boots" do
      assert_widget_in_registry("sample_custom")
    end

    test "host widget appears in Tiler.widgets.types" do
      assert_includes Tiler.widgets.types, "sample_custom"
    end

    test "host widget exposes its declared label + default size" do
      klass = Tiler.widgets["sample_custom"]
      assert_equal "Sample Custom", klass.label
      assert_widget_default_size("sample_custom", w: 4, h: 2)
    end

    test "host widget renders against config without raising" do
      data = widget_data("sample_custom",
                         config: { greeting: "hello world" },
                         dashboard: @dash)
      assert_equal "hello world", data[:greeting]
    end
  end
end
