require "application_system_test_case"

module Tiler
  class WidgetScrollPolicyTest < ApplicationSystemTestCase
    include Engine.routes.url_helpers

    # cavekit-dashboard-layout R2 AC4: assert computed `overflow` per widget class.
    # Allowlisted widgets opt into scroll (auto/scroll); all others clip via the
    # grid-scoped `.tiler-grid-stack .tiler-panel-body { overflow: hidden }` rule.
    SCROLL_ALLOWLIST = %w[list table status_grid text].freeze

    setup do
      @source = create_data_source
      5.times { create_record(@source, { status: "ok", duration: 100.0 }) }
      @dash = create_dashboard(name: "Scroll Policy")

      Tiler.widgets.types.sort.each_with_index do |type, idx|
        klass = Tiler.widgets[type]
        config_default = klass.default_config.dup
        case type
        when "metric", "number_with_delta"
          config_default["aggregation"] ||= "count"
        when "line_chart"
          config_default["bucket"] ||= "1d"
          config_default["series"] ||= [ { label: "duration", column: "duration", agg: "avg" } ]
        when "bar_chart"
          config_default["aggregation"] ||= "count"
          config_default["group_column"] ||= "status"
          config_default["value_column"] ||= "duration"
        when "pie_chart"
          config_default["group_column"] ||= "status"
          config_default["aggregation"] ||= "count"
        when "list"
          config_default["label_column"] ||= "status"
          config_default["aggregation"] ||= "count"
        when "status_grid"
          config_default["group_column"] ||= "status"
          config_default["status_column"] ||= "status"
        when "table"
          config_default["limit"] ||= 5
        end
        create_panel(@dash, title: type.humanize, widget_type: type,
                     data_source: @source,
                     x: (idx % 4) * 3, y: (idx / 4) * 2,
                     width: 3, height: 2,
                     config: config_default.to_json)
      end
    end

    test "panel body has overflow:hidden by default; allowlisted widgets opt into scroll" do
      visit dashboard_path(@dash.slug)
      assert_selector ".grid-stack-item", count: Tiler.widgets.types.size, wait: 10
      # Wait for at least one widget to render so the inner partial classes exist.
      assert_selector ".tiler-panel-body", wait: 10

      report = page.evaluate_script(<<~JS, SCROLL_ALLOWLIST)
        (function(allowlist) {
          var allowed = new Set(allowlist);
          var bad = [];
          var items = document.querySelectorAll('.grid-stack-item');
          items.forEach(function(item) {
            var body = item.querySelector('.tiler-panel-body');
            if (!body) return;
            var partialEl = body.querySelector('[class*="tiler-"]');
            var className = partialEl ? partialEl.className : '';
            // Capture full widget class including hyphenated multi-word names
            // (e.g. tiler-status-grid). Underscore form is used for the allowlist.
            var match = className.match(/tiler-([a-z]+(?:[-_][a-z]+)*)/);
            var widgetClassHtml = match ? match[1] : null;
            if (!widgetClassHtml) return;
            var widgetClassKey = widgetClassHtml.replace(/-/g, '_');

            var bodyOverflow = window.getComputedStyle(body).overflow;
            // Default contract: panel body always overflow:hidden.
            if (bodyOverflow !== 'hidden') {
              bad.push({ widget: widgetClassKey, where: 'panel-body', got: bodyOverflow });
            }

            if (allowed.has(widgetClassKey)) {
              // Allowlisted widgets must have a child with overflow:auto/scroll.
              var contentEl = body.querySelector('.tiler-' + widgetClassHtml);
              if (contentEl) {
                var contentOverflow = window.getComputedStyle(contentEl).overflow;
                if (!['auto', 'scroll'].includes(contentOverflow)) {
                  bad.push({ widget: widgetClassKey, where: 'content', got: contentOverflow,
                             expected: 'auto/scroll' });
                }
              }
            }
          });
          return bad;
        })(arguments[0]);
      JS

      assert_empty report, "Scroll policy violations: #{report.inspect}"
    end
  end
end
