require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class BarChartQuery < Query::Base
      DEFAULT_LIMIT = 10

      def call
        group_col = config["group_column"]
        val_col   = config["value_column"]
        agg       = config["aggregation"] || "sum"
        limit     = (config["limit"] || DEFAULT_LIMIT).to_i.clamp(1, 50)

        return { labels: [], datasets: [], options: {} } if group_col.blank?

        groups = distinct_values(group_col).first(limit)
        data   = groups.map { |g| aggregate_for_group(group_col, g, val_col, agg) }
        # Per catalog: bars use the full viz palette in registration order.
        colors = groups.each_index.map { |i| chart_colors[i % chart_colors.size] }

        {
          labels: groups,
          datasets: [
            {
              label: (val_col || agg).to_s.humanize,
              data: data,
              backgroundColor: colors.map { |c| "#{c}cc" },
              borderColor: colors,
              borderWidth: 1
            }
          ],
          options: {}
        }
      end

      private

      def aggregate_for_group(group_col, group_val, col, agg)
        scoped = apply_filters(
          source.data_records
                .then { |s| time_window_start ? s.where("recorded_at >= ?", time_window_start) : s }
                .where("json_extract(payload, ?) = ?", "$.#{group_col}", group_val.to_s)
        )
        aggregate(scoped, col, agg)
      end
    end

    class BarChart < Widget
      self.type        = "bar_chart"
      self.partial     = "tiler/widgets/bar_chart"
      self.label       = "Bar Chart"
      self.query_class = BarChartQuery
      self.default_config = { "aggregation" => "sum", "limit" => 10 }
      self.default_size   = { w: 6, h: 3 }

      def empty?(data)
        return true if super
        data.nil? || data[:labels].blank? || data[:datasets].blank? ||
          data[:datasets].all? { |ds| Array(ds[:data]).all? { |v| v.nil? || v.zero? } }
      end

      def self.example_config
        { "group_column" => "service", "value_column" => "count",
          "aggregation" => "sum", "limit" => 10 }
      end

      def self.example_payload
        { "service" => "api", "count" => 142 }
      end

      def self.example_preview
        {
          "labels" => %w[api web worker cron db cdn],
          "datasets" => [
            { "label" => "count",
              "data" => [ 142, 98, 64, 22, 180, 55 ],
              "backgroundColor" => [ "#3b82f6cc", "#10b981cc", "#f59e0bcc",
                                     "#ef4444cc", "#8b5cf6cc", "#06b6d4cc" ],
              "borderColor" => [ "#3b82f6", "#10b981", "#f59e0b",
                                 "#ef4444", "#8b5cf6", "#06b6d4" ],
              "borderWidth" => 1 }
          ],
          "options" => {}
        }
      end
    end
  end
end

Tiler.widgets.register("bar_chart", klass: Tiler::Widgets::BarChart)
