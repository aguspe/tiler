require "tiler/widget"

module Tiler
  class WidgetRegistry
    def initialize
      @widgets = {}
    end

    def register(type, klass: nil, partial: nil, label: nil, query: nil, col_spans: [ 1, 2 ])
      type = type.to_s
      klass ||= build_anonymous(type, partial:, label:, query:, col_spans:)
      @widgets[type] = klass
    end

    def [](type)
      @widgets[type.to_s]
    end

    # Drop a widget from the registry. Used by Tiler::UserWidget when a
    # no-code widget row is destroyed.
    def unregister(type)
      @widgets.delete(type.to_s)
    end

    def fetch(type)
      @widgets.fetch(type.to_s) { raise Error, "Unknown widget type: #{type}" }
    end

    def types
      @widgets.keys
    end

    def each(&block)
      @widgets.each(&block)
    end

    def options_for_select
      @widgets.map { |type, klass| [ klass.label, type ] }
    end

    private

    def build_anonymous(type, partial:, label:, query:, col_spans:)
      Class.new(Widget) do
        self.type       = type
        self.partial    = partial || "tiler/widgets/#{type}"
        self.label      = label || type.humanize
        self.query_class = query
        self.col_spans  = col_spans
      end
    end
  end
end
