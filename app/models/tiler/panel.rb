module Tiler
  class Panel < ApplicationRecord
    self.table_name = "tiler_panels"

    belongs_to :dashboard,   class_name: "Tiler::Dashboard",  foreign_key: :tiler_dashboard_id
    belongs_to :data_source, class_name: "Tiler::DataSource", foreign_key: :tiler_data_source_id, optional: true

    validates :title,       presence: true
    validates :widget_type, presence: true
    validates :col_span,    inclusion: { in: [ 1, 2 ] }
    validates :position,    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate  :widget_type_registered

    before_validation :assign_default_position, on: :create

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

    private

    def assign_default_position
      self.position ||= (dashboard&.panels&.maximum(:position) || -1) + 1
    end

    def widget_type_registered
      return if Tiler.widgets[widget_type]
      errors.add(:widget_type, "is not a registered widget")
    end
  end
end
