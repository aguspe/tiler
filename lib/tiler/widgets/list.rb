require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class ListQuery < Query::Base
      VALID_ORDERS = %w[asc desc].freeze

      def call
        label_col = config["label_column"]
        agg       = config["aggregation"] || "count"
        val_col   = config["value_column"]
        limit     = (config["limit"] || 10).to_i.clamp(1, 100)
        order     = config["order"].to_s.downcase
        order     = "desc" unless VALID_ORDERS.include?(order)

        return { items: [] } if label_col.blank?

        labels = distinct_values(label_col)
        items = labels.map do |g|
          scope = apply_filters(
            source.data_records
                  .then { |s| time_window_start ? s.where("recorded_at >= ?", time_window_start) : s }
                  .where("json_extract(payload, ?) = ?", "$.#{label_col}", g.to_s)
          )
          { label: g, value: aggregate(scope, val_col, agg) }
        end
        items = items.sort_by { |i| i[:value].to_f }
        items = items.reverse if order == "desc"
        { items: items.first(limit) }
      end
    end

    class List < Widget
      self.type        = "list"
      self.partial     = "tiler/widgets/list"
      self.label       = "List"
      self.query_class = ListQuery
      self.default_config = { "limit" => 10, "order" => "desc" }
      self.default_size   = { w: 6, h: 3 }

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
