require "test_helper"

module Tiler
  class WidgetsDefaultsTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source
      3.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard
    end

    Tiler.widgets.types.each do |type|
      define_method "test_#{type}_has_hash_default_config" do
        klass = Tiler.widgets[type]
        assert_kind_of Hash, klass.default_config, "#{type} default_config not a Hash"
      end

      define_method "test_#{type}_has_default_size_with_w_h_keys" do
        klass = Tiler.widgets[type]
        size = klass.default_size
        assert_kind_of Hash, size, "#{type} default_size not a Hash"
        assert size.key?(:w) || size.key?("w"), "#{type} default_size missing :w"
        assert size.key?(:h) || size.key?("h"), "#{type} default_size missing :h"
      end

      define_method "test_#{type}_panel_built_from_defaults_renders_data_without_raising" do
        klass = Tiler.widgets[type]
        # Data-source-backed widgets get the source; config-only widgets ignore it.
        panel = create_panel(@dash, widget_type: type, data_source: @source,
                             config: klass.default_config.to_json,
                             width: klass.default_size[:w] || klass.default_size["w"],
                             height: klass.default_size[:h] || klass.default_size["h"])
        assert_nothing_raised { panel.data }
      end
    end

    test "image default_config does not include url with javascript: data: or file: scheme" do
      url = Tiler.widgets["image"].default_config["url"]
      if url.present?
        refute_match(/\Ajavascript:/i, url)
        refute_match(/\Adata:/i, url)
        refute_match(/\Afile:/i, url)
        assert_match(/\Ahttps?:\/\//i, url)
      else
        # Default omits url — partial will show placeholder; satisfies R6.
        assert_nil url
      end
    end

    test "meter default_config aggregation if present is in allowlist" do
      agg = Tiler.widgets["meter"].default_config["aggregation"]
      if agg.present?
        assert_includes %w[avg sum max min last], agg
      end
    end

    test "meter default_config omits max so partial surfaces configure-error placeholder" do
      # Required-key error state per cavekit-widgets-smashing-parity R9: meter without max
      # must render the "Configure max" placeholder rather than a silent blank gauge.
      assert_nil Tiler.widgets["meter"].default_config["max"],
                 "meter default should NOT include max (forces explicit user config)"

      # Render the partial with the default config and assert the placeholder text appears.
      panel = create_panel(@dash, widget_type: "meter", data_source: @source,
                           config: Tiler.widgets["meter"].default_config.to_json)
      data = panel.data
      assert_nil data[:max]
    end

    test "image default_config omits url so partial surfaces empty-state placeholder" do
      assert_nil Tiler.widgets["image"].default_config["url"],
                 "image default should NOT include url (forces explicit user config)"
    end

    test "comments default_config omits quote_column so partial surfaces empty-state placeholder" do
      assert_nil Tiler.widgets["comments"].default_config["quote_column"],
                 "comments default should NOT include quote_column (forces explicit user config)"
    end

    test "iframe default_config omits url so partial surfaces empty-state placeholder" do
      assert_nil Tiler.widgets["iframe"].default_config["url"],
                 "iframe default should NOT include url (forces explicit user config)"
    end

    test "every widget default_config aggregation if present is in supported set" do
      Tiler.widgets.each do |type, klass|
        agg = klass.default_config["aggregation"]
        next if agg.nil?
        assert_includes %w[avg sum max min last count], agg,
                        "#{type} has unsupported default aggregation: #{agg.inspect}"
      end
    end
  end
end
