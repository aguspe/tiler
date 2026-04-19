require "tiler/version"
require "tiler/configuration"
require "tiler/widget_registry"
require "tiler/engine"

module Tiler
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def widgets
      @widgets ||= WidgetRegistry.new
    end

    def register_widget(type, **opts, &block)
      widgets.register(type, **opts, &block)
    end
  end
end
