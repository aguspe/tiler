require "application_system_test_case"

# End-to-end resize tests. Every tile must:
#   - expose draggable resize handles on every edge + corner (n,s,e,w + 4 corners)
#   - cursor switches to a resize cursor when hovering a handle
#   - resizing clamps to the widget's min/max bounds (1..12)
#   - the new dimensions persist via the layout PATCH endpoint
#
# Driving the actual mouse drag of a sub-pixel handle is flaky in headless
# Chrome — instead we use gridstack's public API (`grid.update(el, ...)`)
# which is exactly what the user-driven drag wires into. Anything the API
# rejects (out-of-bound sizes) the user can't reach via dragging either.
module Tiler
  class PanelResizeTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash  = create_dashboard(name: "Resize #{SecureRandom.hex(3)}")
      preview = { "_preview" => { "value" => 42, "label" => "rps" } }.to_json
      @panel = create_panel(@dash, title: "Resize Me", widget_type: "metric",
                            data_source: nil,
                            x: 0, y: 0, width: 4, height: 3, config: preview)
    end

    test "every tile has resize handles on all four edges and four corners" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@panel.id}']", visible: :all, wait: 5
      sleep 0.2 # let gridstack inject handles

      handles = page.evaluate_script(<<~JS)
        (function() {
          var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
          return Array.from(item.querySelectorAll(".ui-resizable-handle"))
                      .map(function(h) {
                        var dirs = ["n","s","e","w","ne","nw","se","sw"];
                        for (var i = 0; i < dirs.length; i++) {
                          if (h.classList.contains("ui-resizable-" + dirs[i])) return dirs[i];
                        }
                        return null;
                      }).filter(Boolean);
        })();
      JS
      %w[n s e w ne nw se sw].each do |dir|
        assert_includes handles, dir, "missing ui-resizable-#{dir} handle (got #{handles.inspect})"
      end
    end

    test "resize handles use a resize cursor when hovered" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@panel.id}']", visible: :all, wait: 5
      sleep 0.2

      cursors = page.evaluate_script(<<~JS)
        (function() {
          var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
          var out = {};
          ["n","s","e","w","ne","nw","se","sw"].forEach(function(d) {
            var h = item.querySelector(".ui-resizable-" + d);
            if (h) out[d] = window.getComputedStyle(h).cursor;
          });
          return out;
        })();
      JS
      # Browsers/gridstack may report either the bidirectional or directional
      # cursor name (ns-resize vs n-resize) — both are valid resize cursors.
      assert_match(/ns-resize|n-resize|s-resize/,           cursors["n"])
      assert_match(/ns-resize|s-resize|n-resize/,           cursors["s"])
      assert_match(/ew-resize|e-resize|w-resize/,           cursors["e"])
      assert_match(/ew-resize|w-resize|e-resize/,           cursors["w"])
      assert_match(/nwse-resize|nw-resize|se-resize/,       cursors["nw"])
      assert_match(/nwse-resize|se-resize|nw-resize/,       cursors["se"])
      assert_match(/nesw-resize|ne-resize|sw-resize/,       cursors["ne"])
      assert_match(/nesw-resize|sw-resize|ne-resize/,       cursors["sw"])
    end

    test "resizing via gridstack API persists new dimensions and clamps to 1..12" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@panel.id}']", visible: :all, wait: 5
      sleep 0.2

      # Grow to 8x5
      page.execute_script(<<~JS)
        var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
        var grid = document.querySelector(".grid-stack").gridstack;
        grid.update(item, { w: 8, h: 5 });
      JS
      Timeout.timeout(5) { sleep 0.1 until @panel.reload.width == 8 && @panel.height == 5 }
      assert_equal 8, @panel.width
      assert_equal 5, @panel.height

      # Try to grow beyond 12 — gridstack must clamp at 12
      page.execute_script(<<~JS)
        var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
        var grid = document.querySelector(".grid-stack").gridstack;
        grid.update(item, { w: 99, h: 99 });
      JS
      sleep 0.5
      @panel.reload
      assert_operator @panel.width,  :<=, 12, "width must clamp to 12 (got #{@panel.width})"
      assert_operator @panel.height, :<=, 12, "height must clamp to 12 (got #{@panel.height})"

      # Try to shrink below 1 — must clamp at 1
      page.execute_script(<<~JS)
        var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
        var grid = document.querySelector(".grid-stack").gridstack;
        grid.update(item, { w: 0, h: 0 });
      JS
      sleep 0.5
      @panel.reload
      assert_operator @panel.width,  :>=, 1, "width must clamp to 1 (got #{@panel.width})"
      assert_operator @panel.height, :>=, 1, "height must clamp to 1 (got #{@panel.height})"
    end

    test "resize handles are visually invisible — no background, no arrow icons" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@panel.id}']", visible: :all, wait: 5
      sleep 0.2
      bg = page.evaluate_script(<<~JS)
        (function() {
          var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
          var out = [];
          item.querySelectorAll(".ui-resizable-handle").forEach(function(h) {
            var s   = window.getComputedStyle(h);
            var bef = window.getComputedStyle(h, "::before");
            var aft = window.getComputedStyle(h, "::after");
            out.push({
              bg:        s.backgroundColor,
              bgImage:   s.backgroundImage,
              befContent: bef.content,
              aftContent: aft.content
            });
          });
          return out;
        })();
      JS
      bg.each do |h|
        assert_match(/rgba\(\s*0\s*,\s*0\s*,\s*0\s*,\s*0\s*\)|transparent/, h["bg"],
                     "handle should be visually transparent (got #{h.inspect})")
        assert_equal "none", h["bgImage"],
                     "handle must not show a corner arrow icon (got #{h.inspect})"
        assert_equal "none", h["befContent"], "::before signifier must be off (#{h.inspect})"
        assert_equal "none", h["aftContent"], "::after signifier must be off (#{h.inspect})"
      end
    end

    test "extreme size swings (1↔12) on one tile keep other tiles resizable" do
      preview = { "_preview" => { "value" => 99 } }.to_json
      a = @panel
      b = create_panel(@dash, title: "B", widget_type: "metric", data_source: nil,
                       x: 0, y: 4, width: 4, height: 2, config: preview)
      c = create_panel(@dash, title: "C", widget_type: "metric", data_source: nil,
                       x: 0, y: 8, width: 4, height: 2, config: preview)
      visit dashboard_path(@dash.slug)
      [ a, b, c ].each { |p| assert_selector ".grid-stack-item[gs-id='#{p.id}']", visible: :all, wait: 5 }
      sleep 0.3

      drive_resize = ->(panel, w, h) do
        page.execute_script(<<~JS, panel.id, w, h)
          var id = arguments[0], w = arguments[1], h = arguments[2];
          var item = document.querySelector(".grid-stack-item[gs-id='" + id + "']");
          var grid = document.querySelector(".grid-stack").gridstack;
          grid.update(item, { w: w, h: h });
        JS
        Timeout.timeout(5) do
          sleep 0.05 until panel.reload.width == w && panel.height == h
        end
      end

      # Slam tile A through the full range; then verify B and C still respond.
      drive_resize.call(a, 12, 1)
      drive_resize.call(a, 1,  12)
      drive_resize.call(a, 6,  3)

      drive_resize.call(b, 7, 4)
      assert_equal 7, b.reload.width
      assert_equal 4, b.height

      drive_resize.call(c, 2, 5)
      assert_equal 2, c.reload.width
      assert_equal 5, c.height
    end

    test "resizing one tile does not break a second tile's resize" do
      preview = { "_preview" => { "value" => 99 } }.to_json
      other = create_panel(@dash, title: "Other", widget_type: "metric",
                           data_source: nil,
                           x: 4, y: 0, width: 3, height: 2, config: preview)
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@panel.id}']", visible: :all, wait: 5
      assert_selector ".grid-stack-item[gs-id='#{other.id}']",  visible: :all, wait: 5
      sleep 0.3

      # Resize the first tile.
      page.execute_script(<<~JS)
        var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
        var grid = document.querySelector(".grid-stack").gridstack;
        grid.update(item, { w: 6, h: 4 });
      JS
      Timeout.timeout(5) { sleep 0.1 until @panel.reload.width == 6 }

      # Now resize the second tile — the bug was that this one wouldn't take.
      page.execute_script(<<~JS)
        var item = document.querySelector(".grid-stack-item[gs-id='#{other.id}']");
        var grid = document.querySelector(".grid-stack").gridstack;
        grid.update(item, { w: 5, h: 3 });
      JS
      Timeout.timeout(5) { sleep 0.1 until other.reload.width == 5 && other.reload.height == 3 }
      assert_equal 5, other.width
      assert_equal 3, other.height
    end

    test "minimum tile size is 1x1 by default (gs-min-w and gs-min-h are 1)" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item", visible: :all, wait: 5
      bounds = page.evaluate_script(<<~JS)
        (function() {
          var item = document.querySelector(".grid-stack-item[gs-id='#{@panel.id}']");
          var n = item.gridstackNode || {};
          return { minW: n.minW, minH: n.minH, maxW: n.maxW, maxH: n.maxH };
        })();
      JS
      assert_equal 1,  bounds["minW"]
      assert_equal 1,  bounds["minH"]
      assert_equal 12, bounds["maxW"]
      assert_equal 12, bounds["maxH"]
    end
  end
end
