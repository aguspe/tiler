require "tiler/widget"

module Tiler
  module Widgets
    class Image < Widget
      ALLOWED_FIT = %w[cover contain fill].freeze
      ALLOWED_SCHEMES = %w[http:// https://].freeze

      self.type        = "image"
      self.partial     = "tiler/widgets/image"
      self.label       = "Image"
      self.query_class = nil

      def data
        {
          url: safe_url(config["url"]),
          alt: config["alt"].to_s,
          fit: safe_fit(config["fit"])
        }
      end

      private

      def safe_url(u)
        s = u.to_s
        ALLOWED_SCHEMES.any? { |scheme| s.start_with?(scheme) } ? s : ""
      end

      def safe_fit(f)
        s = f.to_s
        ALLOWED_FIT.include?(s) ? s : "contain"
      end
    end
  end
end

Tiler.widgets.register("image", klass: Tiler::Widgets::Image)
