require "tiler/widget"

module Tiler
  module Widgets
    class Iframe < Widget
      self.type        = "iframe"
      self.partial     = "tiler/widgets/iframe"
      self.label       = "Iframe"
      self.query_class = nil
      self.default_config = {}
      self.default_size   = { w: 4, h: 3 }

      def data
        { url: config["url"].to_s, sandbox: config["sandbox"] }
      end
    end
  end
end

Tiler.widgets.register("iframe", klass: Tiler::Widgets::Iframe)
