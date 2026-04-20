require "tiler/widget"

module Tiler
  module Widgets
    class Text < Widget
      self.type        = "text"
      self.partial     = "tiler/widgets/text"
      self.label       = "Text"
      self.query_class = nil

      def data
        { text: config["text"].to_s, size: config["size"] || "md" }
      end
    end
  end
end

Tiler.widgets.register("text", klass: Tiler::Widgets::Text)
