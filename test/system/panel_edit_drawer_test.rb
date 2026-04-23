require "application_system_test_case"

# Two complementary checks for the panel edit experience:
#   1. The preview-example snippet shown under the Config textarea must not
#      overflow horizontally — long JSON has to wrap inside the form panel.
#   2. Clicking Edit on the dashboard opens an in-page slide-over drawer
#      instead of navigating away. Closing the drawer (× button) restores
#      the dashboard view.
module Tiler
  class PanelEditDrawerTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash  = create_dashboard(name: "Drawer #{SecureRandom.hex(3)}")
      @panel = create_panel(@dash, title: "Sample Table", widget_type: "table",
                            data_source: nil, x: 0, y: 0, width: 6, height: 3,
                            config: {}.to_json)
    end

    test "preview snippet stays inside the form (no horizontal overflow)" do
      visit edit_dashboard_panel_path(@dash, @panel)
      snippet = find("[data-tiler-preview-example]", wait: 5)
      overflow = page.evaluate_script(<<~JS)
        (function() {
          var el = document.querySelector("[data-tiler-preview-example]");
          var form = document.getElementById("tiler-panel-form");
          return {
            snippetOverflow: el.scrollWidth - el.clientWidth,
            formOverflow:    form.scrollWidth - form.clientWidth,
            snippetRight:    el.getBoundingClientRect().right,
            formRight:       form.getBoundingClientRect().right
          };
        })();
      JS
      assert_operator overflow["snippetOverflow"], :<=, 1,
                      "preview snippet overflows horizontally (#{overflow.inspect})"
      assert_operator overflow["formOverflow"], :<=, 1,
                      "form overflows horizontally (#{overflow.inspect})"
      assert_operator overflow["snippetRight"], :<=, overflow["formRight"] + 2,
                      "preview snippet escapes form bounds (#{overflow.inspect})"
      assert snippet.text.length > 100, "preview JSON should be long enough to test wrapping"
    end

    test "panel header has no Edit link or widget-type tag — clicking the header edits" do
      visit dashboard_path(@dash.slug)
      header = find("turbo-frame#tiler_panel_#{@panel.id} [data-tiler-panel-header]", wait: 5)
      within(header) do
        assert_no_selector "a",            text: /edit/i
        assert_no_selector ".tiler-tag"
      end
      assert_includes header["data-action"], "click->tiler--drawer#openWith"
      assert_includes header["data-tiler--drawer-url-param"],
                      "/panels/#{@panel.id}/edit"
      assert_equal "button", header["role"]
    end

    test "drawer body scrolls independently when the form exceeds viewport height" do
      visit dashboard_path(@dash.slug)
      find("turbo-frame#tiler_panel_#{@panel.id} [data-tiler-panel-header]", wait: 5).click
      assert_selector "[data-tiler-drawer].is-open", visible: :all, wait: 5
      assert_selector "[data-tiler-drawer] .tiler-drawer-body", wait: 5

      metrics = page.evaluate_script(<<~JS)
        (function() {
          var drawer = document.querySelector("[data-tiler-drawer]");
          var body   = drawer.querySelector(".tiler-drawer-body");
          return {
            drawerHeight: drawer.clientHeight,
            bodyHeight:   body.clientHeight,
            bodyScroll:   body.scrollHeight,
            overflowY:    window.getComputedStyle(body).overflowY,
            scrollable:   body.scrollHeight > body.clientHeight + 4
          };
        })();
      JS
      assert_equal "auto", metrics["overflowY"], "drawer body must allow vertical scroll"
      assert metrics["scrollable"],
             "drawer body should scroll for tall forms (got #{metrics.inspect})"

      # Verify scrolling actually moves content within the drawer (not the page behind).
      page_scroll_before = page.evaluate_script("window.scrollY")
      page.execute_script(<<~JS)
        document.querySelector("[data-tiler-drawer] .tiler-drawer-body").scrollTop = 200;
      JS
      after = page.evaluate_script(<<~JS)
        ({ bodyTop: document.querySelector("[data-tiler-drawer] .tiler-drawer-body").scrollTop,
           pageTop: window.scrollY })
      JS
      assert_operator after["bodyTop"], :>=, 100, "drawer body did not scroll"
      assert_equal page_scroll_before, after["pageTop"],
                   "page (not drawer) scrolled instead"
    end

    test "clicking Edit opens an in-page drawer without leaving the dashboard" do
      visit dashboard_path(@dash.slug)
      original_url = page.current_url

      find("turbo-frame#tiler_panel_#{@panel.id} [data-tiler-panel-header]", wait: 5).click

      assert_selector "[data-tiler-drawer].is-open", visible: :all, wait: 5
      assert_text "Edit Panel"
      assert_equal original_url, page.current_url, "Edit should NOT navigate away"

      find("[data-tiler-drawer-close]").click
      assert_no_selector "[data-tiler-drawer].is-open", visible: :all, wait: 5
    end
  end
end
