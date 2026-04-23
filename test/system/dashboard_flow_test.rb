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
      assert_selector ".grid-stack.tiler-editing", wait: 5
    end

    test "Add Panel button toggles palette open/closed" do
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-palette]", visible: :hidden, wait: 5
      click_button "Add Panel"
      assert_selector "[data-tiler-palette]", visible: true, wait: 5
      click_button "Close Palette"
      assert_selector "[data-tiler-palette]", visible: :hidden, wait: 5
    end

    test "drag-drop: moving a panel PATCHes layout and persists x/y" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 5

      # Drag works without any prior click — gridstack is non-static from boot.
      page.execute_script(<<~JS, @metric.id)
        const id = arguments[0];
        const grid = document.querySelector('.grid-stack').gridstack;
        const widget = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
        grid.update(widget.el, { x: 5, y: 3, w: 4, h: 3 });
      JS

      wait_for_panel_persisted(@metric, x: 5, y: 3, w: 4, h: 3)

      @metric.reload
      assert_equal 5, @metric.x
      assert_equal 3, @metric.y
      assert_equal 4, @metric.width
      assert_equal 3, @metric.height
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

    test "drag-drop: move then undo restores position" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 5

      original = { x: @metric.x, y: @metric.y, w: @metric.width, h: @metric.height }

      page.execute_script(<<~JS, @metric.id)
        const id = arguments[0];
        const grid = document.querySelector('.grid-stack').gridstack;
        const w = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
        grid.update(w.el, { x: 2, y: 4, w: 3, h: 2 });
      JS
      wait_for_panel_persisted(@metric, x: 2, y: 4, w: 3, h: 2)

      page.execute_script(<<~JS, @metric.id, original)
        const id = arguments[0];
        const orig = arguments[1];
        const grid = document.querySelector('.grid-stack').gridstack;
        const w = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
        grid.update(w.el, { x: orig.x, y: orig.y, w: orig.w, h: orig.h });
      JS
      wait_for_panel_persisted(@metric, x: original[:x], y: original[:y], w: original[:w], h: original[:h])
    end

    test "drag-drop: two panels moved simultaneously both persist" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 5

      page.execute_script(<<~JS, @metric.id, @clock.id)
        const [mid, cid] = [arguments[0], arguments[1]];
        const grid = document.querySelector('.grid-stack').gridstack;
        const m = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(mid));
        const c = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(cid));
        grid.update(m.el, { x: 0, y: 6, w: 4, h: 2 });
        grid.update(c.el, { x: 8, y: 6, w: 4, h: 2 });
      JS

      wait_for_panel_persisted(@metric, x: 0, y: 6, w: 4, h: 2)
      wait_for_panel_persisted(@clock,  x: 8, y: 6, w: 4, h: 2)
    end

    test "panel Edit link breaks out of the turbo-frame and navigates to edit form" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@metric.id}", wait: 10
      # Eager panel load means the panel preview (with Edit link) is already in the DOM.
      assert_selector "turbo-frame#tiler_panel_#{@metric.id} a", text: "Edit", wait: 10
      within("turbo-frame#tiler_panel_#{@metric.id}") { click_link "Edit" }

      # Should land on the panel edit page, not "Content missing" inside the frame.
      assert_no_text "Content missing"
      assert_text "Title", wait: 5
      assert_text "Widget type", wait: 5
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
  end
end
