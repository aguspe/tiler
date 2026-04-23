require "application_system_test_case"

# Mobile responsive checks for the dashboard. At ≤720px viewport width:
#   - the dashboard collapses to a 1-column gridstack layout
#   - the body must not horizontally overflow (no sideways scroll)
#   - the slide-over edit drawer takes the full viewport width
module Tiler
  class DashboardMobileTest < ActionDispatch::SystemTestCase
    include Engine.routes.url_helpers
    include TilerTestHelpers
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

    setup do
      # Re-size *after* the driver boots so it sticks regardless of which other
      # test class warmed the driver first (Capybara caches the session).
      Capybara.current_session.driver.browser.manage.window.resize_to(390, 844)
      @dash  = create_dashboard(name: "Mobile #{SecureRandom.hex(3)}")
      preview = { "_preview" => { "value" => 42, "label" => "rps" } }.to_json
      @p1 = create_panel(@dash, title: "M1", widget_type: "metric",
                         data_source: nil, x: 0, y: 0, width: 6, height: 2, config: preview)
      @p2 = create_panel(@dash, title: "M2", widget_type: "metric",
                         data_source: nil, x: 6, y: 0, width: 6, height: 2, config: preview)
    end

    test "dashboard does not horizontally overflow on mobile viewport" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@p1.id}", wait: 5
      overflow = page.evaluate_script(<<~JS)
        (function() {
          return {
            innerWidth:  window.innerWidth,
            bodyScroll:  document.body.scrollWidth,
            htmlScroll:  document.documentElement.scrollWidth,
            overflow:    document.documentElement.scrollWidth - window.innerWidth
          };
        })();
      JS
      assert_operator overflow["overflow"], :<=, 1,
                      "dashboard horizontally overflows on mobile: #{overflow.inspect}"
      assert_operator overflow["innerWidth"], :<, 760,
                      "viewport should be a mobile size (got #{overflow["innerWidth"]}px)"
    end

    test "gridstack collapses to 1 column under 720px" do
      visit dashboard_path(@dash.slug)
      assert_selector "turbo-frame#tiler_panel_#{@p1.id}", wait: 5
      sleep 0.3 # let the responsive resize hook run
      cols = page.evaluate_script(<<~JS)
        (function() {
          var grid = document.querySelector(".grid-stack");
          if (!grid || !grid.gridstack) return null;
          return grid.gridstack.getColumn();
        })();
      JS
      assert_equal 1, cols, "gridstack should drop to 1 column on mobile"
    end

    test "edit drawer fills the full viewport on mobile" do
      visit dashboard_path(@dash.slug)
      find("turbo-frame#tiler_panel_#{@p1.id} [data-tiler-panel-header]", wait: 5).click
      assert_selector "[data-tiler-drawer].is-open", visible: :all, wait: 5
      width = page.evaluate_script(<<~JS)
        (function() {
          var d = document.querySelector("[data-tiler-drawer]");
          return d.getBoundingClientRect().width;
        })();
      JS
      assert_in_delta page.evaluate_script("window.innerWidth"), width, 8,
                      "drawer should span viewport on mobile (got #{width}px)"
    end

    teardown do
      # Restore the default desktop size so other system tests aren't poisoned.
      Capybara.current_session.driver.browser.manage.window.resize_to(1400, 1000)
    end
  end
end
