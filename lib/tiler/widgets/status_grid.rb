require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class StatusGridQuery < Query::Base
      PASS = %w[pass passed ok success true].freeze
      FAIL = %w[fail failed error false].freeze
      WARN = %w[flaky warn warning skip skipped].freeze

      def call
        row_col    = config["row_column"]
        status_col = config["status_column"]
        limit      = (config["limit_rows"] || 50).to_i
        return { rows: [] } if row_col.blank? || status_col.blank?

        pass_vals = Array(config["pass_values"].presence || PASS)
        fail_vals = Array(config["fail_values"].presence || FAIL)
        warn_vals = Array(config["warn_values"].presence || WARN)

        groups = distinct_values(row_col).first(limit)
        rows = groups.map do |group_val|
          scope = base_scope.where("json_extract(payload, ?) = ?", "$.#{row_col}", group_val)
          statuses = scope.pluck(Arel.sql(json_extract(status_col)))
          last     = scope.order(recorded_at: :desc).first

          {
            name:        group_val,
            status:      classify(last&.parsed_payload.to_h[status_col], pass_vals, fail_vals, warn_vals),
            last_status: last&.parsed_payload.to_h[status_col],
            pass:        statuses.count { |s| pass_vals.include?(s.to_s.downcase) },
            fail:        statuses.count { |s| fail_vals.include?(s.to_s.downcase) },
            warn:        statuses.count { |s| warn_vals.include?(s.to_s.downcase) },
            total:       statuses.size,
            last_run:    last&.recorded_at&.strftime("%Y-%m-%d %H:%M")
          }
        end
        { rows: rows.sort_by { |r| -r[:fail] } }
      end

      private

      def classify(status, pass_vals, fail_vals, warn_vals)
        s = status.to_s.downcase
        return "fail" if fail_vals.include?(s)
        return "warn" if warn_vals.include?(s)
        return "pass" if pass_vals.include?(s)
        "unknown"
      end
    end

    class StatusGrid < Widget
      self.type        = "status_grid"
      self.partial     = "tiler/widgets/status_grid"
      self.label       = "Status Grid"
      self.query_class = StatusGridQuery
      self.default_config = {}
      self.default_size   = { w: 6, h: 3 }

      def self.example_config
        { "row_column" => "suite", "status_column" => "status", "limit_rows" => 20 }
      end

      def self.example_payload
        { "suite" => "checkout", "status" => "pass" }
      end

      def self.example_preview
        {
          "rows" => [
            { "name" => "checkout",  "status" => "pass", "last_status" => "pass",
              "pass" => 47, "fail" => 0,  "warn" => 0,  "total" => 47, "last_run" => "2026-04-23 09:30" },
            { "name" => "search",    "status" => "warn", "last_status" => "skipped",
              "pass" => 38, "fail" => 0,  "warn" => 4,  "total" => 42, "last_run" => "2026-04-23 09:25" },
            { "name" => "payments",  "status" => "fail", "last_status" => "error",
              "pass" => 22, "fail" => 8,  "warn" => 1,  "total" => 31, "last_run" => "2026-04-23 09:18" },
            { "name" => "auth",      "status" => "pass", "last_status" => "ok",
              "pass" => 51, "fail" => 0,  "warn" => 0,  "total" => 51, "last_run" => "2026-04-23 09:32" }
          ]
        }
      end
    end
  end
end

Tiler.widgets.register("status_grid", klass: Tiler::Widgets::StatusGrid)
