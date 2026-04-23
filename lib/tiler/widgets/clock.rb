require "tiler/widget"

module Tiler
  module Widgets
    class Clock < Widget
      self.type        = "clock"
      self.partial     = "tiler/widgets/clock"
      self.label       = "Clock"
      self.query_class = nil
      self.default_config = {}
      self.default_size   = { w: 3, h: 2 }

      def data
        { timezone: config["timezone"], format: config["format"] || "24h" }
      end
    end
  end
end

Tiler.widgets.register("clock", klass: Tiler::Widgets::Clock)
