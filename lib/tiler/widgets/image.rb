require "tiler/widget"

module Tiler
  module Widgets
    class Image < Widget
      ALLOWED_FIT = %w[cover contain fill].freeze

      self.type        = "image"
      self.partial     = "tiler/widgets/image"
      self.label       = "Image"
      self.query_class = nil
      self.default_config = {}
      self.default_size   = { w: 3, h: 3 }

      def data
        {
          url: safe_url(config["url"]),
          alt: config["alt"].to_s,
          fit: safe_fit(config["fit"])
        }
      end

      private

      def safe_url(u)
        s = u.to_s.strip
        return nil if s.empty?
        prefix = s[0, 8].downcase
        (prefix.start_with?("http://") || prefix.start_with?("https://")) ? s : nil
      end

      def safe_fit(f)
        s = f.to_s
        ALLOWED_FIT.include?(s) ? s : "contain"
      end
    end
  end
end

Tiler.widgets.register("image", klass: Tiler::Widgets::Image)
