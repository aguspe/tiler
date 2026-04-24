require "test_helper"

# Phase B — runtime user-defined (Liquid) widgets.
module Tiler
  class UserWidgetTest < ActiveSupport::TestCase
    setup { Tiler::UserWidget.delete_all }

    test "valid row registers under user_<slug> on save" do
      uw = Tiler::UserWidget.create!(
        slug: "weather", label: "Weather",
        template: "<p>{{ data.value }}</p>",
        data_kind: "config_only", default_w: 4, default_h: 3
      )
      assert_equal "user_weather", uw.registry_slug
      assert_includes Tiler.widgets.types, "user_weather"
    end

    test "destroying the row unregisters the widget" do
      uw = Tiler::UserWidget.create!(slug: "temp_widget", label: "Tmp",
                                     template: "{{ data.value }}", data_kind: "config_only")
      assert_includes Tiler.widgets.types, "user_temp_widget"
      uw.destroy!
      refute_includes Tiler.widgets.types, "user_temp_widget"
    end

    test "rejects malformed slugs" do
      bad = Tiler::UserWidget.new(slug: "Bad-Slug!", label: "x",
                                  template: "x", data_kind: "config_only")
      refute bad.valid?
      assert_includes bad.errors[:slug].join, "lowercase"
    end

    test "rejects unparseable Liquid template" do
      uw = Tiler::UserWidget.new(slug: "broken", label: "x",
                                 template: "{% if no_endif %}", data_kind: "config_only")
      refute uw.valid?
      assert_match(/Liquid parse error/, uw.errors[:template].join)
    end

    test "rejects unsafe column names in query_definition" do
      uw = Tiler::UserWidget.new(slug: "queryx", label: "x", template: "{{ data.value }}",
                                 data_kind: "query",
                                 query_definition: { value_column: "v; DROP TABLE" }.to_json)
      refute uw.valid?
      assert_match(/value_column must be alphanumeric/, uw.errors[:query_definition].join)
    end

    test "rejects unsupported aggregation" do
      uw = Tiler::UserWidget.new(slug: "queryx", label: "x", template: "{{ data.value }}",
                                 data_kind: "query",
                                 query_definition: { aggregation: "drop_table" }.to_json)
      refute uw.valid?
      assert_match(/aggregation must be one of/, uw.errors[:query_definition].join)
    end

    test "render_template substitutes data + panel" do
      uw = Tiler::UserWidget.create!(slug: "render_test", label: "Rt",
                                     template: "<b>{{ panel.title }}: {{ data.value }}</b>",
                                     data_kind: "config_only")
      panel = create_panel(create_dashboard, widget_type: "user_render_test", title: "Hello",
                           config: {}.to_json)
      out = uw.render_template(panel: panel, data: { value: 42 })
      assert_includes out, "<b>Hello: 42</b>"
    end

    test "render_template surfaces errors inline (does not raise)" do
      uw = Tiler::UserWidget.create!(slug: "errwidget", label: "Err",
                                     template: "{{ data.value }}",
                                     data_kind: "config_only")
      panel = create_panel(create_dashboard, widget_type: "user_errwidget",
                           title: "T", config: {}.to_json)
      # Force a runtime error — divide by zero through Liquid's filter pipeline.
      uw.template = "{{ data.value | divided_by: 0 }}"
      out = uw.render_template(panel: panel, data: { value: 10 })
      assert_includes out, "tiler-widget-error"
    end

    test "config_only widget uses panel.config + Liquid template" do
      Tiler::UserWidget.create!(
        slug: "greeting", label: "Greeting",
        template: "<span>{{ config.who | default: 'world' }}</span>",
        data_kind: "config_only"
      )
      klass = Tiler.widgets["user_greeting"]
      panel = create_panel(create_dashboard, widget_type: "user_greeting",
                           config: { who: "Alice" }.to_json)
      assert_nil klass.query_class
      # query_class is nil → Widget#data hits the no-query branch and returns
      # nil. The user_widget partial reads only `panel`/`config` in this mode,
      # so the data hash is not consulted; nil is the expected shape.
      assert_nil panel.data
    end

    test "register_all! re-registers every persisted row" do
      Tiler::UserWidget.create!(slug: "one", label: "One", template: "1", data_kind: "config_only")
      Tiler::UserWidget.create!(slug: "two", label: "Two", template: "2", data_kind: "config_only")
      Tiler.widgets.unregister("user_one")
      Tiler.widgets.unregister("user_two")
      Tiler::UserWidget.register_all!
      assert_includes Tiler.widgets.types, "user_one"
      assert_includes Tiler.widgets.types, "user_two"
    end
  end
end
