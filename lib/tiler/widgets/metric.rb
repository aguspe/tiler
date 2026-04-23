require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class MetricQuery < Query::Base
      def call
        col = config["value_column"]
        agg = config["aggregation"] || "last"
        {
          value:       aggregate(base_scope, col, agg),
          label:       panel.title,
          prefix:      config["prefix"].to_s,
          suffix:      config["suffix"].to_s,
          aggregation: agg,
          time_window: config["time_window"]
        }
      end
    end

    class Metric < Widget
      self.type        = "metric"
      self.partial     = "tiler/widgets/metric"
      self.label       = "Single Metric"
      self.query_class = MetricQuery
      self.default_config = { "aggregation" => "last", "time_window" => "24h" }
      self.default_size   = { w: 3, h: 2 }

      # Defer to Tiler::Widget#empty? — empty when no data_source AND no preview.
      def self.example_config
        { "aggregation" => "avg", "value_column" => "duration",
          "time_window" => "24h", "suffix" => "ms" }
      end

      def self.example_payload
        { "status" => "ok", "duration" => 142.3 }
      end

      def self.example_preview
        { "value" => 142, "label" => "Sample metric",
          "prefix" => "", "suffix" => "ms",
          "aggregation" => "avg", "time_window" => "24h" }
      end
    end
  end
end

Tiler.widgets.register("metric", klass: Tiler::Widgets::Metric)
