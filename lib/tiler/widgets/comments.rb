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
            cols = [Arel.sql(json_extract(quote_col))]
            cols << (name_col.present? && safe_col?(name_col) ? Arel.sql(json_extract(name_col)) : Arel.sql("NULL"))
            cols << (avatar_col.present? && safe_col?(avatar_col) ? Arel.sql(json_extract(avatar_col)) : Arel.sql("NULL"))

            base_scope.order(recorded_at: :desc).limit(limit)
                      .pluck(*cols)
                      .map do |row|
                        {
                          quote:  row[0].to_s,
                          name:   row[1].nil? ? nil : row[1],
                          avatar: safe_url(row[2])
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
        s = u.to_s.strip
        return nil if s.empty?
        prefix = s[0, 8].downcase
        (prefix.start_with?("http://") || prefix.start_with?("https://")) ? s : nil
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
