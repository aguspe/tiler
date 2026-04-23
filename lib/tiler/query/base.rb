module Tiler
  module Query
    class Base
      SAFE_COLUMN_RE = /\A[a-zA-Z0-9_]+\z/

      attr_reader :panel, :config, :source

      def initialize(panel, config)
        @panel  = panel
        @config = config || {}
        @source = panel.data_source
      end

      def call
        raise NotImplementedError
      end

      private

      def base_scope
        return DataRecord.none unless source
        scope = source.data_records
        scope = scope.where("recorded_at >= ?", time_window_start) if time_window_start
        apply_filters(scope)
      end

      def apply_filters(scope)
        filters = config["filter"].presence || {}
        filters.each do |key, value|
          next unless safe_col?(key)
          scope = scope.where("json_extract(payload, ?) = ?", "$.#{key}", value.to_s)
        end
        scope
      end

      def time_window_start
        return @_tw if defined?(@_tw)
        @_tw = case config["time_window"]
        when "today"    then Time.current.beginning_of_day
        when "24h"      then 24.hours.ago
        when "7d"       then 7.days.ago
        when "30d"      then 30.days.ago
        when "all", nil then nil
        end
      end

      def safe_col!(col)
        raise ArgumentError, "Unsafe column: #{col.inspect}" unless safe_col?(col)
        col
      end

      def safe_col?(col)
        col.to_s.match?(SAFE_COLUMN_RE)
      end

      def json_extract(col)
        "json_extract(payload, '$.#{safe_col!(col)}')"
      end

      def aggregate(scope, col, agg)
        return scope.count if agg == "count" || col.blank?
        case agg.to_s
        when "sum"  then scope.sum(Arel.sql("CAST(#{json_extract(col)} AS REAL)")).to_f.round(2)
        when "avg"  then scope.average(Arel.sql("CAST(#{json_extract(col)} AS REAL)"))&.to_f&.round(2)
        when "min"  then scope.minimum(Arel.sql("CAST(#{json_extract(col)} AS REAL)"))
        when "max"  then scope.maximum(Arel.sql("CAST(#{json_extract(col)} AS REAL)"))
        when "last" then scope.order(recorded_at: :desc).limit(1).pluck(Arel.sql(json_extract(col))).first
        else scope.count
        end
      end

      def distinct_values(col)
        base_scope.where("#{json_extract(col)} IS NOT NULL")
                  .distinct.pluck(Arel.sql(json_extract(col))).compact
      end

      # The default visualization palette. Per-panel `palette` config (array
      # of hex) or `color` config (single hex broadcast across N entries)
      # overrides it; otherwise the design-system defaults win.
      DEFAULT_CHART_COLORS = %w[
        #3b82f6 #10b981 #f59e0b #ef4444 #8b5cf6 #06b6d4 #f97316 #84cc16 #ec4899 #6366f1
      ].freeze
      HEX_COLOR_RE = /\A#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\z/i

      def chart_colors
        palette = sanitize_palette(config["palette"])
        return palette if palette.any?
        single = sanitize_color(config["color"])
        return [ single ] if single
        DEFAULT_CHART_COLORS
      end

      def sanitize_color(c)
        return nil unless c.is_a?(String)
        s = c.strip
        s.match?(HEX_COLOR_RE) ? s : nil
      end

      def sanitize_palette(arr)
        Array(arr).filter_map { |c| sanitize_color(c) }
      end
    end
  end
end
