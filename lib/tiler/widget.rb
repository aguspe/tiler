module Tiler
  class Widget
    class << self
      attr_accessor :type, :partial, :label, :query_class, :col_spans,
                    :default_config, :default_size, :min_size, :max_size
    end

    self.col_spans      = [ 1, 2 ]
    self.default_config = {}
    self.default_size   = { w: 6, h: 2 }
    # Resize bounds enforced by gridstack (gs-min-w/min-h/max-w/max-h).
    # Sensible defaults — every tile must be at least 1x1 and at most the
    # full 12-col width / a generous 12 rows tall. Subclasses override.
    self.min_size       = { w: 1, h: 1 }
    self.max_size       = { w: 12, h: 12 }

    attr_reader :panel, :config

    def initialize(panel)
      @panel  = panel
      @config = panel.parsed_config
    end

    def data
      # Static-preview escape hatch: if config carries a `_preview` key, use
      # that as the widget's data and skip the query entirely. Lets users
      # paste arbitrary JSON into the Config field to preview a widget
      # without wiring up a data source.
      preview = config["_preview"]
      if preview.present?
        return preview.is_a?(Hash) ? preview.deep_symbolize_keys : preview
      end
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

    # Default rule for the global "configure your panel" empty state:
    #   - Data-backed widget (query_class set) with no data source and no
    #     preview data → empty.
    #   - Config-only widgets (clock/text/iframe/image: query_class nil)
    #     never trigger this — they render their own placeholders.
    # Subclasses override for stricter checks (e.g. chart widgets look for
    # empty datasets even when a data source IS attached).
    def empty?(data)
      return false unless self.class.query_class
      return false if config["_preview"].present?
      panel.data_source.nil?
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

    # An example data hash matching the shape this widget's partial expects.
    # Wrapped under `{"_preview": ...}` and shown on the edit form so users
    # can paste it into Config to test the widget without a data source.
    # Return nil for config-only widgets (clock/text/iframe/image) — they
    # render their own placeholders and don't benefit from preview JSON.
    def self.example_preview
      nil
    end
  end
end
