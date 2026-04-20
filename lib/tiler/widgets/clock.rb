require "tiler/widget"

module Tiler
  module Widgets
    class Clock < Widget
      self.type        = "clock"
      self.partial     = "tiler/widgets/clock"
      self.label       = "Clock"
      self.query_class = nil

      def data
        { timezone: config["timezone"], format: config["format"] || "24h" }
      end
    end
  end
end

Tiler.widgets.register("clock", klass: Tiler::Widgets::Clock)
