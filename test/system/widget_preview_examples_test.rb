require "application_system_test_case"

# Each data-backed widget ships with a built-in _preview example that the
# user can paste into Config to render the widget without a data source.
module Tiler
  class WidgetPreviewExamplesTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard(name: "Examples #{SecureRandom.hex(3)}")
    end

    PREVIEWABLE = %w[metric number_with_delta table list bar_chart line_chart
                     pie_chart status_grid comments meter].freeze

    PREVIEWABLE.each do |type|
      define_method "test_#{type}_edit_page_shows_a_preview_example_snippet" do
        panel = create_panel(@dash, title: type.humanize, widget_type: type,
                             data_source: nil,
                             x: 0, y: 0, width: 4, height: 3, config: {}.to_json)
        visit edit_dashboard_panel_path(@dash, panel)
        snippet = find("[data-tiler-preview-example]", wait: 5)
        json = JSON.parse(snippet.text)
        assert json.key?("_preview"),
               "#{type} preview example should be wrapped under '_preview' (got #{snippet.text[0, 200]})"
        refute json["_preview"].nil?
      end

      define_method "test_pasting_#{type}_preview_renders_the_widget" do
        klass = Tiler.widgets[type]
        preview = { "_preview" => klass.example_preview }
        panel = create_panel(@dash, title: "Preview #{type}", widget_type: type,
                             data_source: nil,
                             x: 0, y: 0, width: 6, height: 3,
                             config: preview.to_json)
        visit dashboard_path(@dash.slug)
        assert_selector "turbo-frame#tiler_panel_#{panel.id}", wait: 5
        # Asserts the empty-state DID NOT render — the preview took over.
        assert_no_selector "turbo-frame#tiler_panel_#{panel.id} .tiler-panel-empty"
      end
    end

    test "config-only widgets (clock) do NOT show a preview example" do
      panel = create_panel(@dash, title: "Clock", widget_type: "clock",
                           data_source: nil,
                           x: 0, y: 0, width: 3, height: 2, config: {}.to_json)
      visit edit_dashboard_panel_path(@dash, panel)
      assert_no_selector "[data-tiler-preview-example]"
    end
  end
end
