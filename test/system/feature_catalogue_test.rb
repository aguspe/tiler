require "application_system_test_case"

# Feature-by-feature smoke catalogue. Every shipped capability gets at least
# one assertion here — if a regression sneaks past a focused test, this will
# usually still trip. Keeps the surface area visible at a glance.
module Tiler
  class FeatureCatalogueTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Catalogue #{SecureRandom.hex(3)}")
      preview = { "_preview" => { "value" => 42 } }.to_json
      @panel = create_panel(@dash, title: "Demo", widget_type: "metric",
                            data_source: nil, x: 0, y: 0, width: 4, height: 2,
                            config: preview)
    end

    # ---------- Empty-dashboard onboarding ----------

    test "empty dashboard paints a No tiles yet overlay over the drop surface" do
      empty = create_dashboard(name: "Onboard #{SecureRandom.hex(3)}")
      visit dashboard_path(empty.slug)
      overlay = find("[data-tiler-empty-grid]", wait: 5)
      assert_text(/no tiles yet/i)
      assert_text(/add panel/i)
      # Overlay sits on top of the grid (absolute, pointer-events:none) so it
      # never blocks the drop target.
      pe = page.evaluate_script(<<~JS)
        window.getComputedStyle(document.querySelector("[data-tiler-empty-grid]")).pointerEvents
      JS
      assert_equal "none", pe, "overlay must not intercept clicks/drops"
      pos = page.evaluate_script(<<~JS)
        window.getComputedStyle(document.querySelector("[data-tiler-empty-grid]")).position
      JS
      assert_equal "absolute", pos
    end

    test "empty-state overlay stays centered ON the grid surface — even after the palette opens" do
      empty = create_dashboard(name: "Layout #{SecureRandom.hex(3)}")
      visit dashboard_path(empty.slug)
      assert_selector "[data-tiler-empty-grid]", wait: 5

      before = layout_metrics
      assert overlay_centered_on_grid?(before),
             "overlay must be centered on the grid initially (got #{before.inspect})"

      # Open the palette — this used to stretch the dashboard shell taller
      # than the grid, pushing the overlay below the gray drop surface.
      find("[data-tiler-add-panel]", wait: 5).click
      sleep 0.3
      after_open = layout_metrics
      assert overlay_centered_on_grid?(after_open),
             "overlay must stay centered on the grid after palette opens (got #{after_open.inspect})"
    end

    test "populated dashboard hides the empty-grid card" do
      visit dashboard_path(@dash.slug)
      assert_no_selector "[data-tiler-empty-grid]"
    end

    # ---------- Drag-drop create (no duplication) ----------

    test "dropping a palette widget creates exactly one panel (no duplicate)" do
      before = @dash.panels.count
      visit dashboard_path(@dash.slug)
      find("[data-tiler-add-panel]", wait: 5).click
      sleep 0.3
      drop_palette_widget("metric")
      Timeout.timeout(5) { sleep 0.05 until @dash.panels.count == before + 1 }
      assert_equal before + 1, @dash.panels.count, "exactly one panel should be created per drop"
      # And the DOM must show exactly one tile per persisted panel.
      tiles_in_dom = page.evaluate_script(<<~JS)
        document.querySelectorAll(".grid-stack-item[gs-id]").length
      JS
      assert_equal @dash.panels.count, tiles_in_dom,
                   "DOM tile count must equal DB panel count (got #{tiles_in_dom})"
      # Crucially: the cloned palette element must NOT be left behind in the
      # grid (this was the bug — gridstack v10 setupDragIn with helper:'clone'
      # leaves the original cloned palette item unless removeWidget is told
      # to drop the DOM node).
      ghosts = page.evaluate_script(<<~JS)
        document.querySelectorAll(".grid-stack .tiler-widget-palette-item").length
      JS
      assert_equal 0, ghosts,
                   "cloned palette element must be removed from the grid after a drop (got #{ghosts})"
    end

    test "first drop on a brand-new (empty) dashboard creates exactly one panel" do
      empty = create_dashboard(name: "FirstDrop #{SecureRandom.hex(3)}")
      visit dashboard_path(empty.slug)
      assert_selector "[data-tiler-empty-grid]", wait: 5
      find("[data-tiler-add-panel]", wait: 5).click
      sleep 0.3
      drop_palette_widget("metric")
      Timeout.timeout(5) { sleep 0.05 until empty.panels.count == 1 }
      assert_equal 1, empty.panels.count
      tiles = page.evaluate_script("document.querySelectorAll('.grid-stack-item[gs-id]').length")
      assert_equal 1, tiles, "first drop should produce exactly one tile (got #{tiles})"
      # Empty-state overlay should be gone after the first tile lands.
      assert_no_selector "[data-tiler-empty-grid]", wait: 3
    end

    # ---------- Edit drawer ----------

    test "clicking the panel header opens the edit drawer in place" do
      visit dashboard_path(@dash.slug)
      original_url = page.current_url
      find("turbo-frame#tiler_panel_#{@panel.id} [data-tiler-panel-header]", wait: 5).click
      assert_selector "[data-tiler-drawer].is-open", visible: :all, wait: 5
      assert_equal original_url, page.current_url
    end

    # ---------- Inline rename ----------

    test "double-clicking the dashboard title makes it contenteditable" do
      visit dashboard_path(@dash.slug)
      title = find("[data-tiler-dashboard-title]", wait: 5)
      title.double_click
      editable = page.evaluate_script(<<~JS)
        document.querySelector("[data-tiler-dashboard-title]").getAttribute("contenteditable") === "true"
      JS
      assert editable, "title should toggle to contenteditable on dblclick"
    end

    # ---------- Resize bounds + handles ----------

    test "every tile carries gs-min/max-w/h that gridstack picks up" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item", visible: :all, wait: 5
      sleep 0.2
      bounds = page.evaluate_script(<<~JS)
        (function() {
          var item = document.querySelector(".grid-stack-item[gs-id]");
          var n = item.gridstackNode || {};
          return { minW: n.minW, minH: n.minH, maxW: n.maxW, maxH: n.maxH };
        })();
      JS
      %w[minW minH maxW maxH].each { |k| assert bounds[k].to_i.between?(1, 12) }
    end

    # ---------- Theme tokens ----------

    test "theme tokens emit as inline CSS custom properties on .tiler-dashboard" do
      @dash.update!(settings: { page_bg: "#102030", tile_bg: "#445566" }.to_json)
      visit dashboard_path(@dash.slug)
      style = page.evaluate_script(<<~JS)
        document.querySelector(".tiler-dashboard").getAttribute("style") || ""
      JS
      assert_includes style.downcase, "--paper: #102030"
      assert_includes style.downcase, "--paper-2: #445566"
    end

    # ---------- Hover-to-delete dashboard card ----------

    test "dashboard card carries a hidden-by-default delete button wired to the modal" do
      visit dashboards_path
      btn = find("[data-tiler-dashboard-card='#{@dash.slug}'] [data-tiler-dashboard-delete]",
                 visible: :all, wait: 5)
      assert_includes btn["data-controller"], "tiler--modal"
      opacity = page.evaluate_script(<<~JS)
        window.getComputedStyle(
          document.querySelector("[data-tiler-dashboard-card='#{@dash.slug}'] [data-tiler-dashboard-delete]")
        ).opacity
      JS
      assert_equal "0", opacity
    end

    # ---------- Custom widget admin (no-code) ----------

    test "custom widgets index has a primary New button + clickable rows" do
      Tiler::UserWidget.delete_all
      Tiler::UserWidget.create!(slug: "feat_test", label: "Feat",
                                template: "x", data_kind: "config_only")
      visit user_widgets_path
      assert_selector ".tiler-page-header-actions a.tiler-btn-primary", text: /new custom widget/i, wait: 5
      assert_selector "tr[data-tiler-user-widget-row='feat_test']", wait: 5
    end

    # ---------- Settings ----------

    test "settings page exposes 4 theme color inputs and a Reset button" do
      visit settings_path
      %w[page_bg tile_bg tile_header_bg gutter_bg].each do |key|
        assert_selector "[data-tiler-theme-color='#{key}']", visible: :all, wait: 5
      end
      assert_selector "[data-tiler-reset-theme]"
    end

    private

    # Returns rect metrics for the empty-state overlay and the grid surface.
    def layout_metrics
      page.evaluate_script(<<~JS)
        (function() {
          var ov = document.querySelector("[data-tiler-empty-grid]");
          var gr = document.querySelector(".tiler-grid-stack");
          if (!ov || !gr) return null;
          var or_ = ov.getBoundingClientRect();
          var gr_ = gr.getBoundingClientRect();
          return {
            overlayTop: or_.top, overlayBottom: or_.bottom,
            overlayCenter: or_.top + or_.height / 2,
            gridTop: gr_.top, gridBottom: gr_.bottom,
            gridCenter: gr_.top + gr_.height / 2,
            gridHeight: gr_.height
          };
        })();
      JS
    end

    # Overlay center must sit inside the grid AND be near the grid's center.
    def overlay_centered_on_grid?(m)
      return false if m.nil?
      inside  = m["overlayCenter"] >= m["gridTop"] && m["overlayCenter"] <= m["gridBottom"]
      near    = (m["overlayCenter"] - m["gridCenter"]).abs <= [ m["gridHeight"] * 0.15, 24 ].max
      inside && near
    end

    # Drives a palette → grid drop via the documented gridstack API: builds a
    # placeholder node + dispatches a 'dropped' event with the captured
    # widget. Mirrors what setupDragIn does on a real mouse drag.
    def drop_palette_widget(widget_type)
      page.execute_script(<<~JS, widget_type)
        var type = arguments[0];
        var src  = document.querySelector(".tiler-widget-palette-item[data-widget-type='" + type + "']");
        if (!src) throw new Error("palette item missing for " + type);
        // Mirror Stimulus paletteDragStart.
        document.querySelector("[data-controller~='tiler--dashboard-grid']").__stimulusController?.paletteDragStart;
        var ctl = window.Stimulus.getControllerForElementAndIdentifier(
          document.querySelector("[data-controller~='tiler--dashboard-grid']"),
          "tiler--dashboard-grid"
        );
        ctl._draggedWidget = {
          widgetType: type,
          title: src.querySelector(".tiler-widget-palette-label").textContent.trim(),
          defaultConfig: src.getAttribute("data-default-config") || "{}",
          defaultW: parseInt(src.getAttribute("data-default-w"), 10),
          defaultH: parseInt(src.getAttribute("data-default-h"), 10)
        };
        // Emit the 'dropped' event the same way gridstack would after a real drop.
        var grid = document.querySelector(".grid-stack").gridstack;
        // Append a placeholder div so gridstack can hand it to handleDrop.
        var placeholder = document.createElement("div");
        placeholder.className = "grid-stack-item";
        placeholder.setAttribute("gs-w", ctl._draggedWidget.defaultW);
        placeholder.setAttribute("gs-h", ctl._draggedWidget.defaultH);
        document.querySelector(".grid-stack").appendChild(placeholder);
        var node = grid.makeWidget(placeholder).gridstackNode;
        ctl.handleDrop(node);
      JS
    end
  end
end
