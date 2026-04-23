require "application_system_test_case"

# Tile sizing — verifies:
#   1. Each grid item carries the gs-min/max-w/h attrs that gridstack uses to
#      enforce resize bounds (so tiles can be resized but not below a usable size
#      or beyond the grid).
#   2. Widget content renders correctly at small (3x2), medium (6x4), and wide
#      (12x6) sizes — no horizontal overflow inside the panel body.
module Tiler
  class PanelSizingTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Sizing #{SecureRandom.hex(3)}")
    end

    test "every panel emits gs-min/max bounds that gridstack picks up" do
      panel = create_panel(@dash, title: "Bounded Metric", widget_type: "metric",
                           data_source: nil,
                           x: 0, y: 0, width: 3, height: 2,
                           config: { "_preview" => { "value" => 42 } }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item", visible: :all, wait: 5
      bounds = page.evaluate_script(<<~JS)
        (function() {
          var items = document.querySelectorAll(".grid-stack-item");
          var n = null;
          for (var i = 0; i < items.length; i++) {
            if (items[i].gridstackNode) { n = items[i].gridstackNode; break; }
          }
          if (!n) return null;
          return { minW: n.minW, minH: n.minH, maxW: n.maxW, maxH: n.maxH, w: n.w, h: n.h };
        })();
      JS
      assert bounds, "expected at least one gridstack node hydrated"
      %w[minW minH maxW maxH].each do |k|
        v = bounds[k]
        assert v && v.to_i.between?(1, 12), "#{k}=#{v.inspect} out of range"
      end
      assert_operator bounds["minW"], :<=, bounds["w"], "minW must not exceed current width"
      assert_operator bounds["maxW"], :>=, bounds["w"], "maxW must accommodate current width"
    end

    SIZE_CASES = {
      "small (3x2)"  => [ 3,  2 ],
      "medium (6x4)" => [ 6,  4 ],
      "wide (12x6)"  => [ 12, 6 ]
    }.freeze

    SIZE_CASES.each do |label, (w, h)|
      define_method "test_table_widget_#{w}x#{h}_renders_without_horizontal_overflow" do
        preview = {
          "_preview" => {
            "columns" => %w[status duration recorded_at],
            "rows" => [
              [ "ok",    142.3, "2026-04-23 09:00" ],
              [ "ok",    201.0, "2026-04-23 09:05" ],
              [ "error", 3500.0, "2026-04-23 09:07" ]
            ],
            "total" => 3, "limit" => 10
          }
        }
        panel = create_panel(@dash, title: "Table #{label}", widget_type: "table",
                             data_source: nil,
                             x: 0, y: 0, width: w, height: h,
                             config: preview.to_json)
        visit dashboard_path(@dash.slug)
        assert_selector "turbo-frame#tiler_panel_#{panel.id} .tiler-table", wait: 5
        overflow = page.evaluate_script(<<~JS)
          (function() {
            var frame  = document.getElementById("tiler_panel_#{panel.id}");
            var body   = frame.querySelector(".tiler-panel-body");
            var bodyStyle = window.getComputedStyle(body);
            var bodyContent = body.clientWidth
              - parseFloat(bodyStyle.paddingLeft)
              - parseFloat(bodyStyle.paddingRight);
            var scroll = frame.querySelector(".tiler-table-scroll");
            var table  = frame.querySelector(".tiler-table");
            return {
              bodyOverflow:    body.scrollWidth - body.clientWidth,
              wrapperFillsBody: scroll.clientWidth >= bodyContent - 4,
              tableFillsWrapper: table.clientWidth >= scroll.clientWidth - 4
            };
          })();
        JS
        assert_operator overflow["bodyOverflow"], :<=, 1,
                        "panel body overflows horizontally at #{label}: #{overflow.inspect}"
        assert overflow["wrapperFillsBody"],
               "table-scroll wrapper should fill body content area at #{label}: #{overflow.inspect}"
        assert overflow["tableFillsWrapper"],
               "table should fill (or scroll within) the wrapper at #{label}: #{overflow.inspect}"
      end
    end

    test "metric widget renders cleanly at a 2x1 minimum size" do
      panel = create_panel(@dash, title: "Tiny Metric", widget_type: "metric",
                           data_source: nil,
                           x: 0, y: 0, width: 2, height: 1,
                           config: { "_preview" => { "value" => 9, "label" => "ok" } }.to_json)
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{panel.id} .tiler-metric-value", text: "9", wait: 5
      overflow = page.evaluate_script(<<~JS)
        (function() {
          var body = document.querySelector("turbo-frame#tiler_panel_#{panel.id} .tiler-panel-body");
          return body.scrollWidth - body.clientWidth;
        })();
      JS
      assert_operator overflow, :<=, 1, "metric body overflows at min size: #{overflow}"
    end
  end
end
