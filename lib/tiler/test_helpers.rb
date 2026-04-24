module Tiler
  # Shared assertions for testing widgets in either the engine or a host app.
  # Mix into ActiveSupport::TestCase / ActionView::TestCase:
  #
  #   class MyWidgetTest < ActiveSupport::TestCase
  #     include Tiler::WidgetTestHelper
  #     test "renders" do
  #       assert_widget_renders("my_widget", config: { foo: 1 })
  #     end
  #   end
  module WidgetTestHelper
    # Asserts the widget is registered under the given type slug.
    def assert_widget_in_registry(type)
      klass = Tiler.widgets[type.to_s]
      assert klass, "expected '#{type}' in Tiler.widgets registry; got #{Tiler.widgets.types.inspect}"
      klass
    end

    # Asserts the registered class' default_size matches the expected w/h.
    def assert_widget_default_size(type, w:, h:)
      klass = assert_widget_in_registry(type)
      size  = klass.default_size
      actual_w = size[:w] || size["w"]
      actual_h = size[:h] || size["h"]
      assert_equal w, actual_w, "#{type}.default_size width drift"
      assert_equal h, actual_h, "#{type}.default_size height drift"
    end

    # Builds a panel + invokes #data without raising. Returns the data hash.
    def widget_data(type, config: {}, data_source: nil, dashboard: nil)
      dashboard ||= (defined?(create_dashboard) ? create_dashboard : Tiler::Dashboard.create!(name: "T#{SecureRandom.hex(3)}"))
      panel = build_widget_panel(type, dashboard, config: config, data_source: data_source)
      panel.data
    end

    # Renders the widget's partial against the panel's data hash; asserts it
    # produced any HTML at all and returns the rendered string. Requires an
    # ActionView::TestCase (or a class that includes ActionView's render API).
    def assert_widget_renders(type, config: {}, data_source: nil, dashboard: nil)
      raise "assert_widget_renders requires ActionView::TestCase (no #render)" unless respond_to?(:render)
      dashboard ||= (defined?(create_dashboard) ? create_dashboard : Tiler::Dashboard.create!(name: "T#{SecureRandom.hex(3)}"))
      panel = build_widget_panel(type, dashboard, config: config, data_source: data_source)
      data  = panel.data
      html  = render partial: panel.widget.partial, locals: { panel: panel, data: data }
      assert html.present?, "#{type} partial rendered empty for config=#{config.inspect}"
      html
    end

    # True when the widget exposes the per-panel single-color picker on the form.
    def assert_widget_supports_color(type)
      klass = assert_widget_in_registry(type)
      assert klass.supports_color_config?, "#{type} should opt into supports_color_config?"
    end

    private

    def build_widget_panel(type, dashboard, config:, data_source:)
      attrs = {
        title:       "Test #{type}",
        widget_type: type.to_s,
        data_source: data_source,
        x: 0, y: 0, width: 4, height: 3,
        config: config.is_a?(String) ? config : config.to_json
      }
      dashboard.panels.create!(attrs)
    end
  end
end
