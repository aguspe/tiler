module Tiler
  class Widget
    class << self
      attr_accessor :type, :partial, :label, :query_class, :col_spans, :default_config, :default_size
    end

    self.col_spans      = [ 1, 2 ]
    self.default_config = {}
    self.default_size   = { w: 6, h: 2 }

    attr_reader :panel, :config

    def initialize(panel)
      @panel  = panel
      @config = panel.parsed_config
    end

    def data
      return nil if query_class.nil?
      query_class.new(panel, config).call
    end

    def partial
      self.class.partial || "tiler/widgets/#{self.class.type}"
    end

    def label
      self.class.label
    end

    def query_class
      self.class.query_class
    end

    # Override in subclasses that have a meaningful empty state. The panel
    # partial uses this to render a friendly "configure your panel" message
    # instead of a blank widget body. Default: never empty (config-only
    # widgets like clock / text / image render their own placeholders).
    def empty?(data)
      false
    end
  end
end
