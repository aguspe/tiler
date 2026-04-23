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
    end
  end
end

Tiler.widgets.register("status_grid", klass: Tiler::Widgets::StatusGrid)
