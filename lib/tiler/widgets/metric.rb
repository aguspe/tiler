require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class MetricQuery < Query::Base
      def call
        col = config["value_column"]
        agg = config["aggregation"] || "count"
        {
          value:          aggregate(base_scope, col, agg),
          label:          config["label"] || panel.title,
          threshold_warn: config["threshold_warn"],
          threshold_crit: config["threshold_crit"],
          aggregation:    agg,
          time_window:    config["time_window"]
        }
      end
    end

    class Metric < Widget
      self.type        = "metric"
      self.partial     = "tiler/widgets/metric"
      self.label       = "Single Metric"
      self.query_class = MetricQuery
      self.default_config = { "aggregation" => "count" }
      self.default_size   = { w: 3, h: 2 }

      # Defer to Tiler::Widget#empty? — empty when no data_source AND no preview.
      def self.example_config
        { "aggregation" => "avg", "value_column" => "duration", "time_window" => "24h" }
      end

      def self.example_payload
        { "status" => "ok", "duration" => 142.3 }
      end

      def self.example_preview
        { "value" => 142, "label" => "Sample metric", "aggregation" => "avg", "time_window" => "24h" }
      end
    end
  end
end

Tiler.widgets.register("metric", klass: Tiler::Widgets::Metric)
