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
    end
  end
end

Tiler.widgets.register("metric", klass: Tiler::Widgets::Metric)
