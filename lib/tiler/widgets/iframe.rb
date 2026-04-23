require "tiler/widget"

module Tiler
  module Widgets
    class Iframe < Widget
      # Fixed sandbox token list — host pages embed without script/forms or
      # top-navigation hijacks, but can run their own styles + same-origin
      # XHR. Catalog spec: not user-configurable.
      SANDBOX = "allow-scripts allow-same-origin allow-popups".freeze

      self.type        = "iframe"
      self.partial     = "tiler/widgets/iframe"
      self.label       = "Iframe"
      self.query_class = nil
      self.default_config = {}
      self.default_size   = { w: 6, h: 3 }

      def data
        { src: safe_url(config["src"]),
          title: config["title"].to_s,
          sandbox: SANDBOX }
      end

      private

      def safe_url(u)
        s = u.to_s.strip
        return nil if s.empty?
        prefix = s[0, 8].downcase
        (prefix.start_with?("http://") || prefix.start_with?("https://")) ? s : nil
      end
    end
  end
end

Tiler.widgets.register("iframe", klass: Tiler::Widgets::Iframe)
