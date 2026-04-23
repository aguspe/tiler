require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class ListQuery < Query::Base
      def call
        group_col = config["group_by"]
        agg       = config["aggregation"] || "count"
        val_col   = config["value_column"]
        limit     = (config["limit"] || 10).to_i.clamp(1, 100)

        return { items: [] } if group_col.blank?

        groups = distinct_values(group_col)
        items = groups.map do |g|
          scope = apply_filters(
            source.data_records
                  .then { |s| time_window_start ? s.where("recorded_at >= ?", time_window_start) : s }
                  .where("json_extract(payload, ?) = ?", "$.#{group_col}", g.to_s)
          )
          { label: g, value: aggregate(scope, val_col, agg) }
        end.sort_by { |i| -i[:value].to_f }.first(limit)

        { items: items }
      end
    end

    class List < Widget
      self.type        = "list"
      self.partial     = "tiler/widgets/list"
      self.label       = "List"
      self.query_class = ListQuery
      self.default_config = { "limit" => 10 }
      self.default_size   = { w: 4, h: 4 }

      def self.example_preview
        { "items" => [
            { "label" => "ok",    "value" => 47 },
            { "label" => "warn",  "value" => 12 },
            { "label" => "error", "value" => 3 }
        ] }
      end
    end
  end
end

Tiler.widgets.register("list", klass: Tiler::Widgets::List)
