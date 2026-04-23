require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class PieChartQuery < Query::Base
      DEFAULT_LIMIT = 6
      OTHER_LABEL   = "Other".freeze

      def call
        group_col = config["group_column"]
        agg       = config["aggregation"] || "count"
        val_col   = config["value_column"]
        limit     = (config["limit"] || DEFAULT_LIMIT).to_i.clamp(1, 50)

        return empty_result if group_col.blank?

        # Aggregate every group, then sort descending by value so the largest
        # slices win the visible spots. Anything past `limit` collapses into a
        # single "Other" slice (only when there's actually overflow).
        groups = distinct_values(group_col)
        all_pairs = groups.map { |g| [ g, aggregate_for_group(group_col, g, val_col, agg).to_f ] }
                          .sort_by { |(_, v)| -v }

        kept     = all_pairs.first(limit)
        leftover = all_pairs.drop(limit)

        labels = kept.map(&:first)
        data   = kept.map(&:last)
        if leftover.any?
          other_value = leftover.sum { |(_, v)| v }
          if other_value > 0
            labels << OTHER_LABEL
            data   << other_value
          end
        end

        colors = labels.each_index.map { |i| chart_colors[i % chart_colors.size] }
        # Legend on the right at panel widths >= 4 cols (catalog spec); top
        # otherwise so the slices keep room to breathe in narrow tiles.
        legend_pos = panel.width.to_i >= 4 ? "right" : "top"

        {
          labels:   labels,
          datasets: [ { data: data, backgroundColor: colors.map { |c| "#{c}cc" },
                        borderColor: colors, borderWidth: 2 } ],
          options: {
            plugins: { legend: { position: legend_pos } }
          }
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

      def empty_result
        { labels: [], datasets: [], options: {} }
      end
    end

    class PieChart < Widget
      self.type        = "pie_chart"
      self.partial     = "tiler/widgets/pie_chart"
      self.label       = "Pie Chart"
      self.query_class = PieChartQuery
      self.default_config = { "aggregation" => "count", "limit" => 6 }
      self.default_size   = { w: 6, h: 3 }

      def empty?(data)
        return true if super
        data.nil? || data[:labels].blank? || data[:datasets].blank? ||
          data[:datasets].all? { |ds| Array(ds[:data]).all? { |v| v.nil? || v.zero? } }
      end

      def self.supports_color_config?;   true; end
      def self.supports_palette_config?; true; end

      def self.example_config
        { "group_column" => "status", "aggregation" => "count", "limit" => 6 }
      end

      def self.example_payload
        { "status" => "ok" }
      end

      def self.example_preview
        {
          "labels" => %w[ok warn error],
          "datasets" => [
            { "data" => [ 70, 20, 10 ],
              "backgroundColor" => [ "#3b82f6cc", "#f59e0bcc", "#ef4444cc" ],
              "borderColor" => [ "#3b82f6", "#f59e0b", "#ef4444" ],
              "borderWidth" => 2 }
          ],
          "options" => { "plugins" => { "legend" => { "position" => "right" } } }
        }
      end
    end
  end
end

Tiler.widgets.register("pie_chart", klass: Tiler::Widgets::PieChart)
