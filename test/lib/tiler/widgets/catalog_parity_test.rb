require "test_helper"

# Locks every widget's contract to the Tiler Design System catalog
# (Tiler Design System/ui_kits/widgets/WidgetCatalog.jsx) so future drift
# fails CI instead of silently re-introducing renamed config keys or wrong
# default tile sizes.
module Tiler
  class WidgetsCatalogParityTest < ActiveSupport::TestCase
    # Ground truth derived from WidgetCatalog.jsx. Update both this constant
    # and the partial/query if the catalog changes.
    CATALOG = {
      "metric"            => { size: { w: 3, h: 2 }, required: %w[value_column] },
      "number_with_delta" => { size: { w: 3, h: 2 }, required: %w[value_column] },
      "meter"             => { size: { w: 4, h: 3 }, required: %w[value_column max] },
      "clock"             => { size: { w: 3, h: 2 }, required: [] },
      "text"              => { size: { w: 4, h: 3 }, required: %w[body] },
      "status_grid"       => { size: { w: 6, h: 3 }, required: %w[group_column status_column] },
      "comments"          => { size: { w: 6, h: 2 }, required: %w[quote_column] },
      "list"              => { size: { w: 6, h: 3 }, required: %w[label_column value_column] },
      "table"             => { size: { w: 6, h: 3 }, required: %w[columns group_by] },
      "line_chart"        => { size: { w: 8, h: 3 }, required: %w[series] },
      "bar_chart"         => { size: { w: 6, h: 3 }, required: %w[group_column value_column] },
      "pie_chart"         => { size: { w: 6, h: 3 }, required: %w[group_column value_column] },
      "image"             => { size: { w: 4, h: 3 }, required: %w[url] },
      "iframe"            => { size: { w: 6, h: 3 }, required: %w[src] }
    }.freeze

    # Engine-only config keys that the catalog explicitly does NOT list. If a
    # widget reads any of these from `config`, the audit considers it drift
    # and this test should fail. We snapshot per-widget banlists so legitimate
    # internal helpers don't trip the check.
    BANNED_KEYS = {
      "metric"            => %w[threshold_warn threshold_crit label],
      "number_with_delta" => %w[previous_window label],
      "text"              => %w[size],
      "status_grid"       => %w[row_column pass_values fail_values warn_values limit_rows],
      "list"              => %w[group_by],
      "bar_chart"         => %w[group_by y_columns],
      "pie_chart"         => %w[group_by],
      "iframe"            => %w[url sandbox],
      "table"             => %w[sort_column sort_dir],
      "line_chart"        => %w[y_columns value_column]
    }.freeze

    CATALOG.each do |type, spec|
      define_method "test_#{type}_default_size_matches_catalog" do
        klass = Tiler.widgets[type]
        size  = klass.default_size
        w = size[:w] || size["w"]
        h = size[:h] || size["h"]
        assert_equal spec[:size][:w], w, "#{type}.default_size width drift (catalog #{spec[:size]})"
        assert_equal spec[:size][:h], h, "#{type}.default_size height drift (catalog #{spec[:size]})"
      end
    end

    BANNED_KEYS.each do |type, keys|
      define_method "test_#{type}_does_not_read_banned_engine-only_keys" do
        klass = Tiler.widgets[type]
        files = candidate_files_for(type)
        sources = files.map { |f| File.read(f) }.join("\n")
        keys.each do |k|
          refute_match(/config\[\s*["']#{Regexp.escape(k)}["']\s*\]/, sources,
                       "#{type} still reads banned config key '#{k}'")
          # default_config / example_config must also not advertise it.
          assert_nil klass.default_config[k], "#{type}.default_config still includes '#{k}'"
          ex = klass.respond_to?(:example_config) ? klass.example_config : {}
          assert_nil ex[k], "#{type}.example_config still includes '#{k}'"
        end
      end
    end

    private

    def candidate_files_for(type)
      [
        Tiler::Engine.root.join("lib/tiler/widgets/#{type}.rb"),
        Tiler::Engine.root.join("app/views/tiler/widgets/_#{type}.html.erb")
      ].select(&:exist?)
    end
  end
end
