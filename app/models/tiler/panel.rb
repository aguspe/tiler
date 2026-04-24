module Tiler
  class Panel < ApplicationRecord
    self.table_name = "tiler_panels"

    belongs_to :dashboard,   class_name: "Tiler::Dashboard",  foreign_key: :tiler_dashboard_id
    belongs_to :data_source, class_name: "Tiler::DataSource", foreign_key: :tiler_data_source_id, optional: true

    # Real-time updates: broadcast panel CRUD events to the dashboard's Turbo Stream channel.
    # Host apps that opt in via <%= turbo_stream_from @dashboard %> get live updates without polling.
    #
    # We avoid `broadcasts_to ->(panel) { panel.dashboard }` because turbo-rails 2.0.23
    # falls through to `send(stream)` (i.e. send(<Proc>)) when the lambda returns nil —
    # which happens during a Dashboard.destroy cascade: after_destroy_commit fires AFTER
    # the transaction, by which point the parent dashboard row is gone and
    # `panel.dashboard` is nil. Wiring the callbacks ourselves lets us guard that case.
    # Only broadcast updates + destroys. Creation already streams synchronously
    # via panels#create's turbo_stream response (see create.turbo_stream.erb);
    # broadcasting on create too produced a duplicate tile in the originating
    # browser. Other tabs/users get new panels on next dashboard navigation.
    after_update_commit  -> { broadcast_replace_later_to(dashboard) if dashboard }
    after_destroy_commit -> { broadcast_remove_to(dashboard)        if dashboard }

    validates :title,       presence: true
    validates :widget_type, presence: true
    validates :width,       inclusion: { in: 1..12 }
    validates :height,      inclusion: { in: 1..12 }
    validates :x,           numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 11 }
    validates :y,           numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate  :widget_type_registered

    scope :layout_order, -> { order(:y, :x, :id) }

    def parsed_config
      JSON.parse(config.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def widget
      Tiler.widgets.fetch(widget_type).new(self)
    end

    def widget_label
      Tiler.widgets[widget_type]&.label || widget_type.to_s.humanize
    end

    def data
      widget.data
    end

    # Backwards-compat alias for templates that still call col_span.
    def col_span
      width
    end

    private

    def widget_type_registered
      return if Tiler.widgets[widget_type]
      errors.add(:widget_type, "is not a registered widget")
    end
  end
end
