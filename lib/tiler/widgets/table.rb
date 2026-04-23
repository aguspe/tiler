require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class TableQuery < Query::Base
      DEFAULT_LIMIT = 20
      DEFAULT_AGG   = "last".freeze

      def call
        cols     = parse_columns(config["columns"])
        group_by = config["group_by"]
        limit    = (config["limit"] || DEFAULT_LIMIT).to_i.clamp(1, 500)

        return empty_result(cols) if cols.empty? || group_by.blank?
        return empty_result(cols) unless safe_col?(group_by)

        groups = distinct_values(group_by)
        rows = groups.map do |g|
          scope = base_scope.where("json_extract(payload, ?) = ?", "$.#{group_by}", g.to_s)
          [ g ] + cols.map { |c| cell_for(scope, c) }
        end

        # Sort by the first numeric column (descending) for leaderboard feel;
        # falls back to label order if no numeric column was declared.
        first_num = cols.index { |c| c[:num] }
        rows = if first_num
          rows.sort_by { |r| -r[first_num + 1].to_f }
        else
          rows.sort_by { |r| r[0].to_s }
        end

        {
          columns: [ { label: group_by.humanize, num: false } ] + cols,
          rows:    rows.first(limit),
          total:   groups.size,
          limit:   limit
        }
      end

      private

      def parse_columns(raw)
        Array(raw).filter_map do |c|
          next unless c.is_a?(Hash) || c.respond_to?(:[])
          column = c["column"] || c[:column]
          next if column.blank? || !safe_col?(column)
          {
            label: (c["label"] || c[:label] || column.to_s.humanize).to_s,
            column: column.to_s,
            num:   !!(c["num"] || c[:num]),
            agg:   (c["agg"] || c[:agg] || DEFAULT_AGG).to_s
          }
        end
      end

      def cell_for(scope, col)
        v = aggregate(scope, col[:column], col[:agg])
        return v unless col[:num]
        v.is_a?(Numeric) ? v.round(2) : v
      end

      def empty_result(cols)
        { columns: cols, rows: [], total: 0, limit: 0 }
      end
    end

    class Table < Widget
      self.type        = "table"
      self.partial     = "tiler/widgets/table"
      self.label       = "Table"
      self.query_class = TableQuery
      self.default_config = { "limit" => 20, "time_window" => "24h" }
      self.default_size   = { w: 6, h: 3 }

      def empty?(data)
        return true if super
        data.nil? || data[:rows].blank?
      end

      def self.example_config
        {
          "group_by"    => "endpoint",
          "time_window" => "24h",
          "limit"       => 20,
          "columns" => [
            { "label" => "p50", "column" => "p50", "num" => true, "agg" => "avg" },
            { "label" => "p95", "column" => "p95", "num" => true, "agg" => "avg" },
            { "label" => "rpm", "column" => "rpm", "num" => true, "agg" => "sum" }
          ]
        }
      end

      def self.example_payload
        { "endpoint" => "/api/users", "p50" => 22, "p95" => 142, "rpm" => 842 }
      end

      def self.example_preview
        {
          "columns" => [
            { "label" => "Endpoint", "num" => false },
            { "label" => "p50",      "num" => true  },
            { "label" => "p95",      "num" => true  },
            { "label" => "rpm",      "num" => true  }
          ],
          "rows" => [
            [ "/api/users",   "22ms",  "142ms", "842" ],
            [ "/api/orders",  "34ms",  "198ms", "561" ],
            [ "/api/search",  "110ms", "680ms", "410" ],
            [ "/auth/login",  "18ms",  "88ms",  "298" ]
          ],
          "total" => 4, "limit" => 20
        }
      end
    end
  end
end

Tiler.widgets.register("table", klass: Tiler::Widgets::Table)
