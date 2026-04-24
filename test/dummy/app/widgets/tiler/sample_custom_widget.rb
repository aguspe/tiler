# Test fixture — exercises the host-app widget extension path. Tiler eager-
# loads everything under app/widgets/** at boot, then this file's
# Tiler.widgets.register call adds the widget to the global registry.
require "tiler/widget"

module Tiler
  class SampleCustomWidget < ::Tiler::Widget
    self.type        = "sample_custom"
    self.partial     = "tiler/widgets/sample_custom"
    self.label       = "Sample Custom"
    self.query_class = nil
    self.default_config = { "greeting" => "hi" }
    self.default_size   = { w: 4, h: 2 }

    def data
      { greeting: config["greeting"].to_s }
    end
  end
end

Tiler.widgets.register("sample_custom", klass: Tiler::SampleCustomWidget)
