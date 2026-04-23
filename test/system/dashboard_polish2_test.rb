require "application_system_test_case"

# Round-2 polish:
#  - About paragraph renders as structured content (multiple paragraphs / list)
#  - Config-only widgets (clock/text/iframe/image) hide the "Example: {}"
#    snippet + preview hint when their default config is empty
#  - Settings menu in the dashboard header lets the user dismiss the About panel
module Tiler
  class DashboardPolish2Test < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source
      @dash = create_dashboard(name: "Polish2 #{SecureRandom.hex(3)}")
      @clock = create_panel(@dash, title: "Clock", widget_type: "clock",
                            x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
      @metric = create_panel(@dash, title: "Metric", widget_type: "metric",
                             data_source: @source,
                             x: 3, y: 0, width: 4, height: 2,
                             config: { aggregation: "count" }.to_json)
    end

    test "About panel renders multiple paragraphs (structured, not one wall of text)" do
      visit dashboard_path(@dash.slug)
      assert_selector "[data-tiler-about]", wait: 5
      paragraphs = all("[data-tiler-about] p", visible: :all)
      assert_operator paragraphs.size, :>=, 2,
                      "About panel should be split into multiple paragraphs; got #{paragraphs.size}"
    end

    test "config-only widgets (clock) hide the example snippet when there's nothing to suggest" do
      visit edit_dashboard_panel_path(@dash, @clock)
      # Clock has empty default_config + empty example_config — no example to copy.
      assert_no_selector "[data-tiler-example-config]"
    end

    test "config-only widgets (clock) hide the static-JSON preview hint" do
      visit edit_dashboard_panel_path(@dash, @clock)
      assert_no_text(/paste any static JSON/i)
    end

    test "data-backed widgets (metric) still show the example snippet + preview hint" do
      visit edit_dashboard_panel_path(@dash, @metric)
      assert_selector "[data-tiler-example-config]", wait: 5
      assert_text(/paste any static JSON/i)
    end

    test "global nav has a Settings link" do
      visit dashboard_path(@dash.slug)
      assert_selector ".tiler-nav a", text: "Settings", wait: 5
    end
  end
end
