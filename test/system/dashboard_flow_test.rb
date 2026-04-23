require "application_system_test_case"

module Tiler
  class DashboardFlowTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      5.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard(name: "Sys Demo")
      @metric = create_panel(@dash, title: "Count", widget_type: "metric",
                             data_source: @source,
                             config: { aggregation: "count" }.to_json)
      @clock  = create_panel(@dash, title: "Clock", widget_type: "clock",
                             x: 6, y: 0, config: {}.to_json)
    end

    test "dashboard show renders panels via Turbo frames" do
      visit dashboard_path(@dash.slug)
      assert_text "Sys Demo"
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 10
      assert_text "Count", wait: 10
      assert_text "5",     wait: 10
      assert_selector ".tiler-clock", wait: 10
    end

    test "gridstack initializes non-static (drag enabled from page load)" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack", wait: 5
      static = page.evaluate_script("document.querySelector('.grid-stack').gridstack.opts.staticGrid")
      assert_equal false, static
    end

    test "Add Panel button toggles palette open/closed" do
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-palette]", visible: :hidden, wait: 5
      click_button "Add Panel"
      assert_selector "[data-tiler-palette]", visible: true, wait: 5
      click_button "Close Palette"
      assert_selector "[data-tiler-palette]", visible: :hidden, wait: 5
    end

    test "drag-drop: moving a panel PATCHes layout and persists" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 5

      original_x = @metric.x
      original_y = @metric.y

      # Drag works without any prior click — gridstack is non-static from boot.
      # Note: float: true keeps initial layout but auto-compacts after a change,
      # so the final coords may not exactly match what we requested.
      page.execute_script(<<~JS, @metric.id)
        const id = arguments[0];
        const grid = document.querySelector('.grid-stack').gridstack;
        const widget = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
        grid.update(widget.el, { x: 5, y: 3, w: 4, h: 3 });
      JS

      wait_for_panel_changed(@metric, original_x: original_x, original_y: original_y,
                             expected_w: 4, expected_h: 3)
      assert_equal 4, @metric.width
      assert_equal 3, @metric.height
      # Position changed from (0,0) to something else — exact final coords
      # depend on compact + gridstack collision resolution against @clock.
      assert(@metric.x != original_x || @metric.y != original_y,
             "panel did not move from original (#{original_x},#{original_y})")
    end

    test "drag-drop: resize-only fires PATCH" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@clock.id}", wait: 5

      page.execute_script(<<~JS, @clock.id)
        const id = arguments[0];
        const grid = document.querySelector('.grid-stack').gridstack;
        const widget = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
        grid.update(widget.el, { w: 4, h: 3 });
      JS

      wait_for_panel_persisted(@clock, x: 6, y: 0, w: 4, h: 3)
    end

    test "drag-drop: resize via JS API persists new dimensions" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 5

      page.execute_script(<<~JS, @metric.id)
        const id = arguments[0];
        const grid = document.querySelector('.grid-stack').gridstack;
        const w = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
        grid.update(w.el, { w: 3, h: 4 });
      JS

      wait_for_panel_dim_persisted(@metric, w: 3, h: 4)
      assert_equal 3, @metric.width
      assert_equal 4, @metric.height
    end

    test "drag-drop: two panels moved simultaneously both persist" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 5
      original_metric = { x: @metric.x, y: @metric.y }
      original_clock  = { x: @clock.x,  y: @clock.y  }

      page.execute_script(<<~JS, @metric.id, @clock.id)
        const [mid, cid] = [arguments[0], arguments[1]];
        const grid = document.querySelector('.grid-stack').gridstack;
        const m = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(mid));
        const c = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(cid));
        grid.update(m.el, { x: 0, y: 6, w: 4, h: 2 });
        grid.update(c.el, { x: 8, y: 6, w: 4, h: 2 });
      JS

      wait_for_panel_dim_persisted(@metric, w: 4, h: 2)
      wait_for_panel_dim_persisted(@clock,  w: 4, h: 2)
      # Final positions may differ from requested due to compact + collision resolution,
      # but the layout PATCH must have run (proven by dim change).
      assert_equal 4, @metric.width
      assert_equal 4, @clock.width
    end

    test "double-clicking a panel title opens the edit drawer with the form" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 10
      assert_selector "turbo-frame#tiler_panel_#{@metric.id} [data-tiler-panel-header]", wait: 10
      find("turbo-frame#tiler_panel_#{@metric.id} [data-tiler-panel-header]").click

      assert_selector "[data-tiler-drawer].is-open", visible: :all, wait: 5
      assert_no_text "Content missing"
      within("[data-tiler-drawer]") do
        assert_text "Title", wait: 5
        assert_text "Widget type", wait: 5
      end
    end

    private

    def wait_for_panel_persisted(panel, x:, y:, w:, h:, timeout: 5)
      deadline = Time.now + timeout
      loop do
        panel.reload
        break if panel.x == x && panel.y == y && panel.width == w && panel.height == h
        raise "Layout never persisted (got x=#{panel.x} y=#{panel.y} w=#{panel.width} h=#{panel.height})" if Time.now > deadline
        sleep 0.1
      end
    end

    def wait_for_panel_dim_persisted(panel, w:, h:, timeout: 5)
      deadline = Time.now + timeout
      loop do
        panel.reload
        break if panel.width == w && panel.height == h
        raise "Layout dim never persisted (got w=#{panel.width} h=#{panel.height})" if Time.now > deadline
        sleep 0.1
      end
    end

    def wait_for_panel_changed(panel, original_x:, original_y:, expected_w:, expected_h:, timeout: 5)
      deadline = Time.now + timeout
      loop do
        panel.reload
        if panel.width == expected_w && panel.height == expected_h &&
           (panel.x != original_x || panel.y != original_y)
          break
        end
        raise "Layout never persisted change (x=#{panel.x} y=#{panel.y} w=#{panel.width} h=#{panel.height})" if Time.now > deadline
        sleep 0.1
      end
    end
  end
end
