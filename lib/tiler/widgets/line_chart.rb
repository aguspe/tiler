require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class LineChartQuery < Query::Base
      def call
        y_cols = Array(config["y_columns"].presence || [ config["value_column"] ]).compact
        agg    = config["aggregation"] || "sum"
        bucket = config["bucket"] || "day"

        buckets = time_buckets(bucket)
        labels  = buckets.map { |b| format_label(b, bucket) }

        datasets = y_cols.each_with_index.map do |col, i|
          color = chart_colors[i % chart_colors.size]
          data  = buckets.map { |b| aggregate_for_bucket(b, bucket, col, agg) }
          { label: col.humanize, data: data, borderColor: color,
            backgroundColor: "#{color}33", tension: 0.3, fill: false, spanGaps: true }
        end

        { labels: labels, datasets: datasets, options: {} }
      end

      private

      def time_buckets(bucket)
        return [] unless time_window_start
        step = { "hour" => 1.hour, "day" => 1.day, "week" => 1.week }[bucket] || 1.day
        t = bucket == "hour" ? time_window_start.beginning_of_hour : time_window_start.beginning_of_day
        buckets = []
        while t < Time.current
          buckets << t
          t += step
        end
        buckets
      end

      def aggregate_for_bucket(start, bucket, col, agg)
        stop = case bucket
        when "hour" then start + 1.hour
        when "week" then start + 1.week
        else start + 1.day
        end
        scoped = apply_filters(source.data_records.where(recorded_at: start...stop))
        aggregate(scoped, col, agg)
      end

      def format_label(t, bucket)
        case bucket
        when "hour" then t.strftime("%m/%d %H:%M")
        when "week" then "W#{t.strftime('%-W')} #{t.strftime('%b %-d')}"
        else t.strftime("%b %-d")
        end
      end
    end

    class LineChart < Widget
      self.type        = "line_chart"
      self.partial     = "tiler/widgets/line_chart"
      self.label       = "Line Chart"
      self.query_class = LineChartQuery
      self.default_config = { "bucket" => "day", "time_window" => "7d", "aggregation" => "count" }
      self.default_size   = { w: 6, h: 3 }

      def empty?(data)
        data.nil? || data[:datasets].blank? ||
          data[:datasets].all? { |ds| Array(ds[:data]).all? { |v| v.nil? || v.zero? } }
      end

      def self.example_config
        { "value_column" => "duration", "aggregation" => "avg",
          "bucket" => "day", "time_window" => "7d" }
      end

      def self.example_payload
        { "status" => "ok", "duration" => 142.3 }
      end
    end
  end
end

Tiler.widgets.register("line_chart", klass: Tiler::Widgets::LineChart)
