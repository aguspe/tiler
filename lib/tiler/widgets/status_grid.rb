require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class StatusGridQuery < Query::Base
      # Catalog states map to four tokens. Built-in vocabulary covers most
      # health-check payloads; custom value lists are out of scope per spec.
      PASS = %w[pass passed ok success true].freeze
      FAIL = %w[fail failed error false].freeze
      WARN = %w[flaky warn warning skip skipped].freeze
      DEFAULT_LIMIT = 50

      def call
        group_col  = config["group_column"]
        status_col = config["status_column"]
        sub_col    = config["sub_column"]
        limit      = DEFAULT_LIMIT
        return { rows: [] } if group_col.blank? || status_col.blank?

        groups = distinct_values(group_col).first(limit)
        rows = groups.map do |group_val|
          scope = base_scope.where("json_extract(payload, ?) = ?", "$.#{group_col}", group_val)
          statuses = scope.pluck(Arel.sql(json_extract(status_col)))
          last     = scope.order(recorded_at: :desc).first
          payload  = last&.parsed_payload.to_h

          {
            name:        group_val,
            status:      classify(payload[status_col]),
            last_status: payload[status_col],
            sub:         (sub_col.present? ? payload[sub_col] : nil),
            pass:        statuses.count { |s| PASS.include?(s.to_s.downcase) },
            fail:        statuses.count { |s| FAIL.include?(s.to_s.downcase) },
            warn:        statuses.count { |s| WARN.include?(s.to_s.downcase) },
            total:       statuses.size,
            last_run:    last&.recorded_at&.strftime("%Y-%m-%d %H:%M")
          }
        end
        { rows: rows.sort_by { |r| -r[:fail] } }
      end

      private

      def classify(status)
        s = status.to_s.downcase
        return "fail" if FAIL.include?(s)
        return "warn" if WARN.include?(s)
        return "pass" if PASS.include?(s)
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
        { "group_column" => "suite", "status_column" => "status",
          "sub_column" => "duration", "time_window" => "24h" }
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
