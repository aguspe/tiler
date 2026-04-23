require "tiler/widget"

module Tiler
  module Widgets
    class Text < Widget
      self.type        = "text"
      self.partial     = "tiler/widgets/text"
      self.label       = "Text"
      self.query_class = nil
      ALLOWED_ALIGN = %w[left center].freeze

      self.default_config = { "body" => "Edit me", "align" => "left" }
      self.default_size   = { w: 4, h: 3 }

      def data
        align = config["align"].to_s
        align = "left" unless ALLOWED_ALIGN.include?(align)
        { body: config["body"].to_s, align: align }
      end
    end
  end
end

Tiler.widgets.register("text", klass: Tiler::Widgets::Text)
