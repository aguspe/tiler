require "tiler/widget"

module Tiler
  module Widgets
    class Text < Widget
      self.type        = "text"
      self.partial     = "tiler/widgets/text"
      self.label       = "Text"
      self.query_class = nil
      self.default_config = { "text" => "Edit me", "size" => "md" }
      self.default_size   = { w: 4, h: 2 }

      def data
        { text: config["text"].to_s, size: config["size"] || "md" }
      end
    end
  end
end

Tiler.widgets.register("text", klass: Tiler::Widgets::Text)
