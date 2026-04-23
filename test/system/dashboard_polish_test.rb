require "application_system_test_case"

# Polish pass on the dashboard + edit pages:
#  - Edit page: actions row inside the white form card, Back link, custom
#    delete confirmation modal, copy-to-clipboard buttons on token + JSON.
#  - Dashboard show: About info header, Add Panel under the title with
#    smaller size matching the design system.
module Tiler
  class DashboardPolishTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      @dash = create_dashboard(name: "Polish #{SecureRandom.hex(3)}")
      @panel = create_panel(@dash, title: "Editable", widget_type: "metric",
                            data_source: @source,
                            x: 0, y: 0, width: 4, height: 2,
                            config: { aggregation: "count" }.to_json)
    end

    test "edit page form-actions row is inside the white form card" do
      visit edit_dashboard_panel_path(@dash, @panel)
      assert_selector ".tiler-form .tiler-form-actions", wait: 5
    end

    test "edit page has a link back to the dashboard" do
      visit edit_dashboard_panel_path(@dash, @panel)
      back = find("[data-tiler-back]", wait: 5)
      assert_includes back["href"], dashboard_path(@dash.slug)
      label = back["aria-label"] || back.text
      assert_match(/close|back|dashboard/i, label)
    end

    test "delete button opens a custom modal (not a native confirm)" do
      visit edit_dashboard_panel_path(@dash, @panel)
      delete_btn = find("[data-tiler-delete]", wait: 5)
      delete_btn.click
      # Modal appears in the DOM and is visible.
      assert_selector ".tiler-modal", visible: true, wait: 5
      assert_selector ".tiler-modal [data-tiler-modal-cancel]", wait: 2
      assert_selector ".tiler-modal [data-tiler-modal-confirm]", wait: 2
    end

    test "modal Cancel closes the modal without deleting" do
      visit edit_dashboard_panel_path(@dash, @panel)
      find("[data-tiler-delete]", wait: 5).click
      assert_selector ".tiler-modal", visible: true, wait: 5
      find("[data-tiler-modal-cancel]").click
      assert_no_selector ".tiler-modal", wait: 2
      assert Tiler::Panel.exists?(@panel.id)
    end

    test "modal Confirm deletes the panel" do
      visit edit_dashboard_panel_path(@dash, @panel)
      find("[data-tiler-delete]", wait: 5).click
      assert_selector ".tiler-modal", visible: true, wait: 5
      find("[data-tiler-modal-confirm]").click
      # Redirects back to dashboard with a flash; panel should be gone.
      assert_text "Panel removed", wait: 5
      refute Tiler::Panel.exists?(@panel.id)
    end

    test "token field shows a copy-to-clipboard button" do
      visit edit_dashboard_panel_path(@dash, @panel)
      assert_selector "[data-tiler-copy]", minimum: 1, wait: 5
    end

    test "config field has a hint that pasting static JSON enables preview" do
      visit edit_dashboard_panel_path(@dash, @panel)
      assert_text(/preview/i, wait: 5)
    end

    test "dashboard show has an About info header explaining Tiler" do
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-about]", wait: 5
    end

    test "Add Panel button sits under the dashboard title (not in the right action zone)" do
      visit dashboard_path(@dash.slug)
      assert_selector "h1", text: @dash.name, wait: 5
      assert_selector "[data-tiler-add-panel]", wait: 5
      # h1 must precede the Add Panel button in DOM order. Use the browser's
      # compareDocumentPosition (4 = follows, 2 = precedes).
      following = page.evaluate_script(<<~JS)
        (function() {
          var h1 = document.querySelector("h1");
          var btn = document.querySelector("[data-tiler-add-panel]");
          return h1.compareDocumentPosition(btn) & Node.DOCUMENT_POSITION_FOLLOWING;
        })();
      JS
      assert following != 0, "Add Panel should appear after the h1 in DOM order"
    end

    test "Add Panel button uses the small-size class" do
      visit dashboard_path(@dash.slug)
      add = find("[data-tiler-add-panel]", wait: 5)
      classes = add[:class].to_s.split
      assert_includes classes, "tiler-btn-sm",
                      "Add Panel should use tiler-btn-sm; got #{classes.inspect}"
    end
  end
end
