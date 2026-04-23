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

    # An example config object for this widget. Shown verbatim on the panel
    # edit form so users can copy-paste a working starting point. Default
    # falls back to the class-level default_config; override per widget for
    # richer examples (e.g. specifying value_column / group_by for charts).
    def self.example_config
      default_config
    end

    # An example payload — one record's JSON shape — that this widget can
    # render against. Used to scaffold sample curl commands on the edit
    # page. Default returns a minimal {status: "ok"} which most widgets
    # can render with default config.
    def self.example_payload
      { "status" => "ok", "value" => 42, "duration" => 142.3 }
    end
  end
end
