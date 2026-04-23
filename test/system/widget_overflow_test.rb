require "application_system_test_case"

module Tiler
  class WidgetOverflowTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    # Widgets in the scroll allowlist (cavekit-dashboard-layout R2) — these are
    # ALLOWED to overflow because they opt into scrolling inside the panel.
    SCROLL_ALLOWLIST = %w[list table status_grid text].freeze

    setup do
      @source = create_data_source
      # Seed enough records that data-backed widgets render meaningful content.
      10.times do |i|
        create_record(@source, { status: i.even? ? "ok" : "error",
                                 duration: 100.0 + i, value: i * 10 })
      end
      @dash = create_dashboard(name: "Overflow Test")

      # Place each widget in its own row at full 12-col width, sized to its
      # registry default_size. The overflow contract is "content fits its
      # configured tile" — we honor each widget's declared default size.
      y = 0
      Tiler.widgets.types.sort.each do |type|
        klass = Tiler.widgets[type]
        size = klass.default_size
        w = (size[:w] || size["w"]).to_i
        h = (size[:h] || size["h"]).to_i
        config_default = klass.default_config.dup
        case type
        when "line_chart", "bar_chart"
          config_default["aggregation"] ||= "count"
          config_default["bucket"] ||= "day"
        when "pie_chart", "list"
          config_default["group_by"] ||= "status"
          config_default["aggregation"] ||= "count"
        when "table"
          config_default["limit"] ||= 5
        end

        create_panel(@dash, title: type.humanize, widget_type: type,
                     data_source: @source,
                     x: 0, y: y, width: w, height: h,
                     config: config_default.to_json)
        y += h
      end
    end

    test "no non-allowlisted widget overflows its tile bounds" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item", count: Tiler.widgets.types.size, wait: 10

      # Wait for at least one widget partial to render so we know turbo frames have settled.
      assert_selector ".grid-stack-item-content .tiler-clock, .grid-stack-item-content .tiler-metric, .grid-stack-item-content .tiler-text", wait: 10

      # Read overflow status for every grid item.
      overflow_report = page.evaluate_script(<<~JS, SCROLL_ALLOWLIST)
        (function(allowlist) {
          var allowed = new Set(allowlist);
          var problems = [];
          var items = document.querySelectorAll('.grid-stack-item');
          items.forEach(function(item) {
            var content = item.querySelector('.grid-stack-item-content');
            if (!content) return;
            var inner = content.querySelector('.tiler-panel-body, .tiler-skeleton');
            if (!inner) return;
            // Determine widget type from the rendered partial root class.
            var partialEl = inner.querySelector('[class*="tiler-"]');
            var className = partialEl ? partialEl.className : '';
            // Strip the "tiler-" prefix and pick first widget-class match.
            var match = className.match(/tiler-([a-z_]+)/);
            var widgetClass = match ? match[1] : null;
            if (widgetClass && allowed.has(widgetClass)) return;
            // Overflow check on the panel-body.
            if (inner.scrollHeight > inner.clientHeight + 1) {
              problems.push({ id: item.getAttribute('gs-id'), widgetClass: widgetClass,
                              scrollH: inner.scrollHeight, clientH: inner.clientHeight });
            }
          });
          return problems;
        })(arguments[0]);
      JS

      assert_empty overflow_report, "Panels overflow their tile: #{overflow_report.inspect}"
    end
  end
end
