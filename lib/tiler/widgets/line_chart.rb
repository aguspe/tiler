require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class LineChartQuery < Query::Base
      VALID_BUCKETS = %w[1h 1d 1w].freeze
      DEFAULT_BUCKET = "1d".freeze
      DEFAULT_AGG    = "sum".freeze

      def call
        series = parse_series(config["series"])
        bucket = VALID_BUCKETS.include?(config["bucket"]) ? config["bucket"] : DEFAULT_BUCKET

        return empty_result if series.empty?

        buckets = time_buckets(bucket)
        labels  = buckets.map { |b| format_label(b, bucket) }

        datasets = series.each_with_index.map do |s, i|
          # Per-series color wins over palette/color override, which wins over
          # the default chart palette. Lets you pin a specific series (e.g.
          # "errors must always be red") regardless of where it sits.
          color = s[:color] || chart_colors[i % chart_colors.size]
          data  = buckets.map { |b| aggregate_for_bucket(b, bucket, s[:column], s[:agg]) }
          { label: s[:label], data: data, borderColor: color,
            backgroundColor: "#{color}33", tension: 0.3, fill: false, spanGaps: true }
        end

        { labels: labels, datasets: datasets, options: {} }
      end

      private

      def parse_series(raw)
        Array(raw).filter_map do |s|
          next unless s.is_a?(Hash) || s.respond_to?(:[])
          column = s["column"] || s[:column]
          next if column.blank? || !safe_col?(column)
          {
            label:  (s["label"] || s[:label] || column.to_s.humanize).to_s,
            column: column.to_s,
            agg:    (s["agg"] || s[:agg] || DEFAULT_AGG).to_s,
            color:  sanitize_color(s["color"] || s[:color])
          }
        end
      end

      def time_buckets(bucket)
        return [] unless time_window_start
        step = bucket_step(bucket)
        t = bucket == "1h" ? time_window_start.beginning_of_hour : time_window_start.beginning_of_day
        out = []
        while t < Time.current
          out << t
          t += step
        end
        out
      end

      def bucket_step(bucket)
        case bucket
        when "1h" then 1.hour
        when "1w" then 1.week
        else 1.day
        end
      end

      def aggregate_for_bucket(start, bucket, col, agg)
        scoped = apply_filters(source.data_records.where(recorded_at: start...(start + bucket_step(bucket))))
        aggregate(scoped, col, agg)
      end

      def format_label(t, bucket)
        case bucket
        when "1h" then t.strftime("%m/%d %H:%M")
        when "1w" then "W#{t.strftime('%-W')} #{t.strftime('%b %-d')}"
        else t.strftime("%b %-d")
        end
      end

      def empty_result
        { labels: [], datasets: [], options: {} }
      end
    end

    class LineChart < Widget
      self.type        = "line_chart"
      self.partial     = "tiler/widgets/line_chart"
      self.label       = "Line Chart"
      self.query_class = LineChartQuery
      self.default_config = { "bucket" => "1d", "time_window" => "7d" }
      self.default_size   = { w: 8, h: 3 }

      def empty?(data)
        return true if super
        data.nil? || data[:datasets].blank? ||
          data[:datasets].all? { |ds| Array(ds[:data]).all? { |v| v.nil? || v.zero? } }
      end

      def self.supports_color_config?;   true; end
      def self.supports_palette_config?; true; end

      def self.example_config
        {
          "time_window" => "7d",
          "bucket"      => "1d",
          "series" => [
            { "label" => "requests", "column" => "rpm",      "agg" => "sum" },
            { "label" => "errors",   "column" => "errors",   "agg" => "sum" }
          ]
        }
      end

      def self.example_payload
        { "rpm" => 2_847, "errors" => 4 }
      end

      def self.example_preview
        {
          "labels" => %w[Mon Tue Wed Thu Fri Sat Sun],
          "datasets" => [
            { "label" => "requests",
              "data" => [ 1800, 2200, 2050, 2600, 2950, 2400, 2847 ],
              "borderColor" => "#3b82f6",
              "backgroundColor" => "#3b82f633",
              "tension" => 0.3, "fill" => false },
            { "label" => "errors×100",
              "data" => [ 12, 8, 15, 10, 5, 7, 4 ],
              "borderColor" => "#10b981",
              "backgroundColor" => "#10b98133",
              "tension" => 0.3, "fill" => false }
          ],
          "options" => {}
        }
      end
    end
  end
end

Tiler.widgets.register("line_chart", klass: Tiler::Widgets::LineChart)
