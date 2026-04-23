require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class BarChartQuery < Query::Base
      def call
        group_col = config["group_by"]
        y_cols    = Array(config["y_columns"].presence || [ config["value_column"] ]).compact
        agg       = config["aggregation"] || "sum"

        return { labels: [], datasets: [] } if group_col.blank?

        groups = distinct_values(group_col)
        datasets = y_cols.each_with_index.map do |col, i|
          color = chart_colors[i % chart_colors.size]
          data  = groups.map { |g| aggregate_for_group(group_col, g, col, agg) }
          { label: col.to_s.humanize, data: data, backgroundColor: "#{color}cc",
            borderColor: color, borderWidth: 1 }
        end
        { labels: groups, datasets: datasets, options: {} }
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
      self.default_config = { "aggregation" => "count" }
      self.default_size   = { w: 4, h: 3 }
    end
  end
end

Tiler.widgets.register("bar_chart", klass: Tiler::Widgets::BarChart)
