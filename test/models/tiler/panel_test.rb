require "test_helper"

module Tiler
  class PanelTest < ActiveSupport::TestCase
    setup { @dash = create_dashboard }

    test "width must be 1..12" do
      p = @dash.panels.build(title: "x", widget_type: "metric", width: 0, height: 1, x: 0, y: 0)
      refute p.valid?
      p.width = 13
      refute p.valid?
      p.width = 6
      assert p.valid?
    end

    test "height must be 1..12" do
      p = @dash.panels.build(title: "x", widget_type: "metric", width: 6, height: 0, x: 0, y: 0)
      refute p.valid?
    end

    test "rejects unknown widget_type" do
      p = @dash.panels.build(title: "x", widget_type: "bogus", width: 6, height: 2, x: 0, y: 0)
      refute p.valid?
      assert_includes p.errors[:widget_type], "is not a registered widget"
    end

    test "parsed_config returns {} on bad JSON" do
      p = create_panel(@dash, config: "not-json")
      assert_equal({}, p.parsed_config)
    end

    test "parsed_config returns parsed hash" do
      p = create_panel(@dash, config: { a: 1 }.to_json)
      assert_equal 1, p.parsed_config["a"]
    end

    test "defaults y/x to 0 at DB level" do
      p = @dash.panels.create!(title: "a", widget_type: "metric", width: 6, height: 2)
      assert_equal 0, p.x
      assert_equal 0, p.y
    end

    test "widget returns registered widget instance" do
      p = create_panel(@dash, widget_type: "metric")
      assert_kind_of Tiler::Widgets::Metric, p.widget
    end

    test "col_span alias returns width" do
      p = create_panel(@dash, width: 7)
      assert_equal 7, p.col_span
    end
  end
end
