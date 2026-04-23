require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class NumberWithDeltaQuery < Query::Base
      def call
        col   = config["value_column"]
        agg   = config["aggregation"] || "count"
        prev  = previous_window_seconds

        current  = aggregate(base_scope, col, agg)
        previous = if prev && time_window_start && source
          scope = apply_filters(
            source.data_records.where(recorded_at: (time_window_start - prev)...time_window_start)
          )
          aggregate(scope, col, agg)
        end

        delta = (current.to_f - previous.to_f) if previous
        pct   = if previous.to_f.nonzero?
          ((current.to_f - previous.to_f) / previous.to_f * 100).round(1)
        end

        {
          value:       current,
          previous:    previous,
          delta:       delta,
          pct:         pct,
          label:       config["label"] || panel.title,
          aggregation: agg,
          time_window: config["time_window"],
          direction:   (delta.to_f.positive? ? :up : (delta.to_f.negative? ? :down : :flat))
        }
      end

      private

      def previous_window_seconds
        case config["previous_window"] || config["time_window"]
        when "24h" then 24.hours
        when "7d"  then 7.days
        when "30d" then 30.days
        when "today" then 1.day
        end
      end
    end

    class NumberWithDelta < Widget
      self.type        = "number_with_delta"
      self.partial     = "tiler/widgets/number_with_delta"
      self.label       = "Number (with delta)"
      self.query_class = NumberWithDeltaQuery
      self.default_config = { "aggregation" => "count", "time_window" => "24h", "previous_window" => "24h" }
      self.default_size   = { w: 3, h: 2 }

      def self.example_preview
        {
          "value" => 142, "previous" => 100, "delta" => 42.0, "pct" => 42.0,
          "label" => "Sample metric", "aggregation" => "count",
          "time_window" => "24h", "direction" => "up"
        }
      end
    end
  end
end

Tiler.widgets.register("number_with_delta", klass: Tiler::Widgets::NumberWithDelta)
