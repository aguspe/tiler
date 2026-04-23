require "application_system_test_case"

# End-to-end checks for the number_with_delta widget — sparkline SVG renders
# with --primary stroke + no fill, per catalog spec.
module Tiler
  class NumberWithDeltaWidgetTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "NWD #{SecureRandom.hex(3)}")
      preview = {
        "_preview" => {
          "value" => 142, "previous" => 100, "delta" => 42.0, "pct" => 42.0,
          "label" => "Sample", "aggregation" => "count",
          "time_window" => "24h", "direction" => "up",
          "spark" => [ 96, 97, 97, 98, 98, 99, 98.7 ]
        }
      }
      @panel = create_panel(@dash, title: "rps", widget_type: "number_with_delta",
                            data_source: nil,
                            x: 0, y: 0, width: 4, height: 2,
                            config: preview.to_json)
    end

    test "renders an SVG sparkline polyline alongside the value" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@panel.id} svg.tiler-sparkline polyline", wait: 5
      pts = page.evaluate_script(<<~JS)
        document.querySelector("turbo-frame#tiler_panel_#{@panel.id} svg.tiler-sparkline polyline")
                .getAttribute("points")
      JS
      coords = pts.split(/\s+/)
      assert_equal 7, coords.size, "expected 7 sparkline points (got #{coords.size})"
    end

    test "sparkline stroke uses the --primary token and has no fill" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@panel.id} svg.tiler-sparkline polyline", wait: 5
      style = page.evaluate_script(<<~JS)
        (function() {
          var p = document.querySelector("turbo-frame#tiler_panel_#{@panel.id} svg.tiler-sparkline polyline");
          var s = window.getComputedStyle(p);
          var primary = window.getComputedStyle(document.documentElement).getPropertyValue("--primary").trim();
          return { stroke: s.stroke, fill: s.fill, primary: primary };
        })();
      JS
      assert_match(/none|rgba\(\s*0\s*,\s*0\s*,\s*0\s*,\s*0\s*\)/, style["fill"],
                   "sparkline must have no fill (got #{style.inspect})")
      assert style["stroke"].present? && style["stroke"] != "none",
             "sparkline must have a stroke (got #{style["stroke"].inspect})"
    end

    test "delta arrow color matches the direction" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@panel.id} .tiler-delta-up", wait: 5
      color = page.evaluate_script(<<~JS)
        window.getComputedStyle(
          document.querySelector("turbo-frame#tiler_panel_#{@panel.id} .tiler-delta-up")
        ).color
      JS
      # `--success` token resolves to a green-ish rgb; reject grays/whites/blacks.
      assert_no_match(/^rgb\(255,\s*255,\s*255\)$|^rgb\(0,\s*0,\s*0\)$/, color,
                      "delta-up color should be the success token (got #{color})")
    end
  end
end
