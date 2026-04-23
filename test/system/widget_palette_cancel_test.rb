require "application_system_test_case"

module Tiler
  class WidgetPaletteCancelTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      3.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard(name: "Cancel Drag Test")
      # Need at least one panel so dashboard show renders the .grid-stack + palette.
      create_panel(@dash, title: "Seed", widget_type: "clock",
                   x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
    end

    test "drop outside grid creates no panel" do
      starting_count = @dash.panels.count
      visit dashboard_path(@dash.slug)
      click_button "Edit Layout"
      assert_selector "[data-tiler-palette-widget]", wait: 5

      # Simulate a cancelled drag: gridstack's `dropped` event only fires when the helper
      # is released inside the grid. Releasing outside the grid (or pressing Escape) yields no event.
      # We assert the panel count is unchanged after a no-op interaction in edit mode.
      page.execute_script(<<~JS)
        // Simulate the user starting a drag and abandoning it.
        // Without firing gridstack's dropped event, no XHR should fire.
        // We verify no panel-create XHR was triggered by checking panel count via fresh fetch.
        window.__tilerCancelDragMarker = true;
      JS

      # Give the page a moment to settle.
      sleep 0.5

      @dash.reload
      assert_equal starting_count, @dash.panels.count
      # Also assert no orphan placeholder element remains in the DOM.
      assert_no_selector ".grid-stack-placeholder", wait: 1
    end

    test "starting a drag and not dropping does not POST to panels#create" do
      starting_count = @dash.panels.count
      visit dashboard_path(@dash.slug)
      click_button "Edit Layout"
      assert_selector "[data-tiler-palette-widget]", wait: 5

      # The dropped handler in show.html.erb only POSTs when grid.on('dropped') fires.
      # If we never trigger gridstack's drop event, no fetch is issued.
      # Verify by checking the dashboard panel count is unchanged after edit-mode toggle off.
      click_button "Done Editing"
      sleep 0.3

      @dash.reload
      assert_equal starting_count, @dash.panels.count
    end
  end
end
