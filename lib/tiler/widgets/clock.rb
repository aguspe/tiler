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
        # show_date defaults true per catalog; only an explicit false hides it.
        show_date = config.key?("show_date") ? !!config["show_date"] : true
        {
          timezone:  config["timezone"],
          format:    config["format"] || "24h",
          show_date: show_date
        }
      end
    end
  end
end

Tiler.widgets.register("clock", klass: Tiler::Widgets::Clock)
