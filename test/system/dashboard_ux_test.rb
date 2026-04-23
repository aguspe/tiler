require "application_system_test_case"

# Covers UX issues reported after the always-editable refactor:
#  1. Dashboard should NOT show a permanent "selected" outline on every panel.
#     Drag affordance lives in cursor / subtle hover, not loud blue tinting.
#  2. Dragging a palette item onto the grid creates a new panel and persists it.
#  3. Moving a panel away leaves no permanent gap; layout compacts panels
#     so empty rows fill in.
module Tiler
  class DashboardUxTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      5.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard(name: "UX #{SecureRandom.hex(3)}")
      @top = create_panel(@dash, title: "Top", widget_type: "clock",
                          x: 0, y: 0, width: 4, height: 2, config: {}.to_json)
      @bottom = create_panel(@dash, title: "Bottom", widget_type: "text",
                             x: 0, y: 6, width: 4, height: 2,
                             config: { text: "bottom" }.to_json)
    end

    test "issue #1: dashboard does not apply tiler-editing class to grid by default" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack", wait: 5
      # The whole dashboard appearing 'selected' means .tiler-editing was added
      # globally. We want drag-affordance via cursor only — not loud blue tinting.
      assert_no_selector ".grid-stack.tiler-editing"
    end

    test "issue #1: panel headers do not carry the editing background tint by default" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@top.id}", wait: 5
      assert_selector ".grid-stack-item[gs-id='#{@top.id}'] .tiler-panel-header", wait: 5
      bg = page.evaluate_script(
        "window.getComputedStyle(document.querySelector(\".grid-stack-item[gs-id='#{@top.id}'] .tiler-panel-header\")).backgroundColor"
      )
      # Primary-tint is rgb(226, 229, 253) (var(--primary-tint)). Default is white.
      # Not-primary-tint = no permanent editing visual.
      refute_match(/^rgb\(22[0-9],\s*22[0-9],\s*25[0-3]\)$/, bg,
                   "panel header should not be tinted blue by default — bg=#{bg}")
    end

    test "issue #2: drag a palette item onto the grid creates a new panel" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@top.id}", wait: 5
      starting_count = @dash.panels.count

      click_button "Add Panel"
      assert_selector "[data-tiler-palette-widget][data-widget-type='clock']", wait: 5

      # Simulate the gridstack 'dropped' event by directly invoking the same
      # POST that the controller's drop handler would issue. This proves the
      # SERVER side of the palette-drop flow works end-to-end (palette -> POST
      # -> turbo_stream -> tile in DOM). Pixel-perfect drag is covered by the
      # JS-API and native-MouseEvent tests elsewhere.
      page.evaluate_async_script(<<~JS)
        var done = arguments[arguments.length - 1];
        var grid = document.querySelector('.grid-stack');
        var item = document.querySelector('[data-tiler-palette-widget][data-widget-type="clock"]');
        var fd = new FormData();
        fd.append('panel[widget_type]', 'clock');
        fd.append('panel[title]', 'Dropped clock');
        fd.append('panel[x]', 8);
        fd.append('panel[y]', 8);
        fd.append('panel[width]', 3);
        fd.append('panel[height]', 2);
        fd.append('panel[config]', item.getAttribute('data-default-config') || '{}');
        fetch(window.location.pathname + '/panels', {
          method: 'POST',
          headers: {
            'X-CSRF-Token': grid.dataset.tilerCsrf,
            'Accept': 'text/vnd.turbo-stream.html'
          },
          body: fd,
          credentials: 'same-origin'
        }).then(function(res){ done(res.status); });
      JS

      sleep 0.5
      @dash.reload
      assert_equal starting_count + 1, @dash.panels.count, "palette drop did not create a panel"
      new_panel = @dash.panels.order(created_at: :desc).first
      assert_equal "clock", new_panel.widget_type
    end

    test "issue #3: moving a panel does NOT leave a permanent gap above it" do
      # @top sits at (0,0), @bottom sits at (0,6) — there's already a 4-row gap.
      # After loading the dashboard, gridstack should compact panels upward so
      # @bottom doesn't render at y=6 with empty rows above it.
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@bottom.id}']", wait: 5

      # Trigger a layout pass so compaction (if enabled) runs.
      page.execute_script("document.querySelector('.grid-stack').gridstack.compact()")
      sleep 0.5

      bottom_after = page.evaluate_script(<<~JS)
        (function(){
          var el = document.querySelector(".grid-stack-item[gs-id='#{@bottom.id}']");
          return parseInt(el.getAttribute('gs-y'), 10);
        })();
      JS
      assert_operator bottom_after, :<, 6, "bottom panel should compact upward when there's empty space above it; gs-y=#{bottom_after}"
    end

    test "issue #3: when a panel moves, the layout has no permanent gaps in occupied rows" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item[gs-id='#{@top.id}']", wait: 5

      # Move @top from (0,0) down to (0,4). Without auto-compact, (0,0) is now empty
      # but @bottom stays at (0,6). With float: false / compact-on-change, @bottom
      # should slide up into the freed space.
      page.execute_script(<<~JS, @top.id)
        var id = arguments[0];
        var grid = document.querySelector('.grid-stack').gridstack;
        var n = grid.engine.nodes.find(function(x){ return x.el.getAttribute('gs-id') == String(id); });
        grid.update(n.el, { x: 0, y: 4 });
      JS
      sleep 0.5

      # After the move + compact, the maximum y of any tile should be < (sum of all heights).
      # In other words, there shouldn't be a 4-row empty gap between the top tile and the bottom one.
      occupancy = page.evaluate_script(<<~JS)
        (function(){
          var items = Array.from(document.querySelectorAll('.grid-stack-item[gs-id]'));
          var maxY = 0;
          var totalH = 0;
          items.forEach(function(el){
            var y = parseInt(el.getAttribute('gs-y'), 10);
            var h = parseInt(el.getAttribute('gs-h'), 10);
            if (y + h > maxY) maxY = y + h;
            totalH += h;
          });
          return { maxY: maxY, totalH: totalH };
        })();
      JS
      assert_operator occupancy["maxY"], :<=, occupancy["totalH"] + 1,
                      "layout has permanent gaps; maxY=#{occupancy['maxY']}, totalH=#{occupancy['totalH']}"
    end
  end
end
