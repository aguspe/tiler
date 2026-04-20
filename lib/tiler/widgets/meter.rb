require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class MeterQuery < Query::Base
      ALLOWED_AGG = %w[avg sum max min last].freeze

      def call
        col = config["value_column"]
        agg_raw = (config["aggregation"].presence || "last").to_s
        agg = ALLOWED_AGG.include?(agg_raw) ? agg_raw : "last"
        min = numeric(config["min"], 0)
        max = numeric(config["max"], nil)
        prefix = config["prefix"]
        suffix = config["suffix"]

        raw = col.present? ? aggregate(base_scope, col, agg) : nil
        clamped = clamp(raw, min, max)

        {
          value:  clamped,
          min:    min,
          max:    max,
          prefix: prefix,
          suffix: suffix
        }
      end

      private

      def numeric(v, default)
        return default if v.nil? || v.to_s.strip.empty?
        Float(v) rescue default
      end

      def clamp(v, min, max)
        return nil if v.nil?
        n = v.to_f
        return n if max.nil?
        return min if n < min
        return max if n > max
        n
      end
    end

    class Meter < Widget
      self.type        = "meter"
      self.partial     = "tiler/widgets/meter"
      self.label       = "Meter"
      self.query_class = MeterQuery
    end
  end
end

Tiler.widgets.register("meter", klass: Tiler::Widgets::Meter)
