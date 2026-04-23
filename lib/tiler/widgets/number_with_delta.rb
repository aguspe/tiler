require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class NumberWithDeltaQuery < Query::Base
      SPARK_BUCKETS = 7

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
          label:       panel.title,
          aggregation: agg,
          time_window: config["time_window"],
          direction:   (delta.to_f.positive? ? :up : (delta.to_f.negative? ? :down : :flat)),
          spark:       sparkline_points(col, agg),
          color:       sanitize_color(config["color"])
        }
      end

      private

      def previous_window_seconds
        case config["delta_window"] || config["time_window"]
        when "24h" then 24.hours
        when "7d"  then 7.days
        when "30d" then 30.days
        when "today" then 1.day
        end
      end

      # Returns an array of SPARK_BUCKETS numeric values across the active
      # time_window — the inline trendline shown next to the value. Honors
      # the `spark` config flag (default true). Returns nil when disabled,
      # when no source/window is set, or when there's nothing to chart.
      def sparkline_points(col, agg)
        return nil if config.key?("spark") && !config["spark"]
        return nil unless source && time_window_start

        window  = Time.current - time_window_start
        step    = window / SPARK_BUCKETS
        buckets = SPARK_BUCKETS.times.map { |i| time_window_start + step * i }
        values  = buckets.map do |start|
          scope = apply_filters(source.data_records.where(recorded_at: start...(start + step)))
          aggregate(scope, col, agg).to_f
        end
        values.all?(&:zero?) ? nil : values
      end
    end

    class NumberWithDelta < Widget
      self.type        = "number_with_delta"
      self.partial     = "tiler/widgets/number_with_delta"
      self.label       = "Number (with delta)"
      self.query_class = NumberWithDeltaQuery
      self.default_config = { "aggregation" => "count", "time_window" => "24h",
                              "delta_window" => "24h", "spark" => true }
      self.default_size   = { w: 3, h: 2 }

      def self.example_preview
        {
          "value" => 142, "previous" => 100, "delta" => 42.0, "pct" => 42.0,
          "label" => "Sample metric", "aggregation" => "count",
          "time_window" => "24h", "direction" => "up",
          "spark" => [ 96, 97, 97, 98, 98, 99, 98.7 ], "color" => nil
        }
      end

      def self.supports_color_config?
        true
      end
    end
  end
end

Tiler.widgets.register("number_with_delta", klass: Tiler::Widgets::NumberWithDelta)
