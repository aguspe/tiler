require "tiler/widget"
require "tiler/query/base"

module Tiler
  module Widgets
    class CommentsQuery < Query::Base
      MAX_LIMIT = 100
      DEFAULT_ROTATE_SECONDS = 8

      def call
        quote_col  = config["quote_column"]
        name_col   = config["name_column"]
        avatar_col = config["avatar_column"]
        limit      = clamp_limit(config["limit"])

        items =
          if quote_col.present? && safe_col?(quote_col)
            scope = base_scope.order(recorded_at: :desc).limit(limit)
            scope.map do |record|
              payload = parse_payload(record)
              {
                quote:  payload[quote_col].to_s,
                name:   name_col.present?   ? payload[name_col]   : nil,
                avatar: avatar_col.present? ? safe_url(payload[avatar_col]) : nil
              }
            end
          else
            []
          end

        items = items.reject { |i| i[:quote].to_s.strip.empty? }

        {
          items:          items,
          rotate_seconds: rotate_seconds
        }
      end

      private

      def safe_url(u)
        s = u.to_s
        (s.start_with?("http://") || s.start_with?("https://")) ? s : nil
      end

      def clamp_limit(v)
        n = (v.presence || 10).to_i
        n = 1 if n < 1
        n = MAX_LIMIT if n > MAX_LIMIT
        n
      end

      def rotate_seconds
        n = config["rotate_seconds"].to_i
        n > 0 ? n : DEFAULT_ROTATE_SECONDS
      end

      def parse_payload(record)
        raw = record.payload
        return raw if raw.is_a?(Hash)
        JSON.parse(raw.to_s)
      rescue JSON::ParserError
        {}
      end
    end

    class Comments < Widget
      self.type        = "comments"
      self.partial     = "tiler/widgets/comments"
      self.label       = "Comments"
      self.query_class = CommentsQuery
    end
  end
end

Tiler.widgets.register("comments", klass: Tiler::Widgets::Comments)
