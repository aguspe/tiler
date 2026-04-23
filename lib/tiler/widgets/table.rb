require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class TableQuery < Query::Base
      def call
        columns  = config["columns"].presence || (source&.schema_column_keys || []) + [ "recorded_at" ]
        sort_col = config["sort_column"] || "recorded_at"
        sort_dir = config["sort_dir"] == "asc" ? :asc : :desc
        limit    = (config["limit"] || 25).to_i.clamp(1, 500)

        records = base_scope.order(recorded_at: sort_dir).limit(limit)
        rows = records.map do |r|
          payload = r.parsed_payload
          columns.map do |c|
            c == "recorded_at" ? r.recorded_at&.strftime("%Y-%m-%d %H:%M") : payload[c]
          end
        end
        { columns: columns, rows: rows, total: base_scope.count, limit: limit }
      end
    end

    class Table < Widget
      self.type        = "table"
      self.partial     = "tiler/widgets/table"
      self.label       = "Table"
      self.query_class = TableQuery
      self.default_config = { "limit" => 10 }
      self.default_size   = { w: 6, h: 4 }

      def self.example_preview
        {
          "columns" => %w[status duration recorded_at],
          "rows" => [
            [ "ok",    142.3, "2026-04-23 09:00" ],
            [ "ok",    201.0, "2026-04-23 09:05" ],
            [ "error", 3500.0, "2026-04-23 09:07" ]
          ],
          "total" => 3, "limit" => 10
        }
      end
    end
  end
end

Tiler.widgets.register("table", klass: Tiler::Widgets::Table)
