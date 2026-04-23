require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class PieChartQuery < Query::Base
      def call
        group_col = config["group_by"]
        agg       = config["aggregation"] || "count"
        val_col   = config["value_column"]

        return { labels: [], datasets: [] } if group_col.blank?

        groups = distinct_values(group_col)
        data   = groups.map { |g| aggregate_for_group(group_col, g, val_col, agg) }
        colors = groups.each_index.map { |i| chart_colors[i % chart_colors.size] }
        {
          labels: groups,
          datasets: [ { data: data, backgroundColor: colors.map { |c| "#{c}cc" },
                        borderColor: colors, borderWidth: 2 } ]
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

    class PieChart < Widget
      self.type        = "pie_chart"
      self.partial     = "tiler/widgets/pie_chart"
      self.label       = "Pie Chart"
      self.query_class = PieChartQuery
      self.default_config = { "aggregation" => "count" }
      self.default_size   = { w: 4, h: 3 }

      def empty?(data)
        data.nil? || data[:labels].blank? || data[:datasets].blank? ||
          data[:datasets].all? { |ds| Array(ds[:data]).all? { |v| v.nil? || v.zero? } }
      end

      def self.example_config
        { "group_by" => "status", "aggregation" => "count" }
      end

      def self.example_payload
        { "status" => "ok" }
      end
    end
  end
end

Tiler.widgets.register("pie_chart", klass: Tiler::Widgets::PieChart)
