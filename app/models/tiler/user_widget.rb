require "liquid"
require "tiler/widget"
require "tiler/query/base"

module Tiler
  # Runtime, no-code widget definition. Each row builds an anonymous
  # Tiler::Widget subclass on boot (and after_save) and registers it under
  # its slug. The Widget renders a partial that evaluates the row's Liquid
  # template against `panel`/`data` — sandboxed, no Ruby execution.
  class UserWidget < ApplicationRecord
    self.table_name = "tiler_user_widgets"

    DATA_KINDS    = %w[config_only query].freeze
    SLUG_RE       = /\A[a-z][a-z0-9_]{2,39}\z/
    TEMPLATE_MAX  = 10_000
    AGGS          = %w[count sum avg min max last].freeze
    SLUG_PREFIX   = "user_".freeze

    validates :slug,
              presence: true,
              uniqueness: { case_sensitive: false },
              format: { with: SLUG_RE,
                        message: "must be lowercase a-z, 0-9 and _ (3-40 chars)" }
    validates :label,    presence: true, length: { maximum: 80 }
    validates :template, presence: true, length: { maximum: TEMPLATE_MAX }
    validates :data_kind, inclusion: { in: DATA_KINDS }
    validates :default_w, :default_h,
              inclusion: { in: 1..12 }
    validate  :query_definition_must_be_safe
    validate  :template_must_parse

    after_save    :register!
    after_destroy :unregister!

    # Slug used inside Tiler.widgets — namespaced so it can't collide with
    # built-in Ruby widgets (e.g. "user_my_thing", not "my_thing").
    def registry_slug
      "#{SLUG_PREFIX}#{slug}"
    end

    def parsed_query_definition
      JSON.parse(query_definition.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def parsed_default_config
      JSON.parse(default_config.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    # Renders the Liquid template against the `data` hash + panel info.
    # Returns the rendered HTML string. Errors are surfaced inline so a
    # broken template doesn't crash the whole dashboard.
    def render_template(panel:, data:)
      tpl = Liquid::Template.parse(template, error_mode: :strict)
      tpl.render!(
        "panel" => liquid_panel(panel),
        "data"  => stringify(data),
        "config" => panel ? stringify(panel.parsed_config) : {}
      )
    rescue Liquid::Error, StandardError => e
      "<pre class=\"tiler-widget-error\">#{ERB::Util.h(e.message)}</pre>".html_safe
    end

    # Build + register the anonymous Widget subclass for this row. Called on
    # save and once at boot via .register_all!
    def register!
      uw = self
      query_kls = build_query_class

      widget_kls = Class.new(::Tiler::Widget) do
        self.type        = uw.registry_slug
        self.partial     = "tiler/widgets/user_widget"
        self.label       = uw.label
        self.query_class = query_kls
        self.default_config = uw.parsed_default_config
        self.default_size   = { w: uw.default_w, h: uw.default_h }
        self.min_size       = { w: 1, h: 1 }
        self.max_size       = { w: 12, h: 12 }
      end

      ::Tiler.widgets.register(uw.registry_slug, klass: widget_kls)
      uw.instance_variable_set(:@widget_class, widget_kls)
      widget_kls
    end

    def unregister!
      ::Tiler.widgets.unregister(registry_slug) if ::Tiler.widgets.respond_to?(:unregister)
    end

    # Iterate every persisted row and (re-)register their widget classes.
    # Called from the engine boot initializer.
    def self.register_all!
      return unless table_exists?
      find_each(&:register!)
    rescue ActiveRecord::StatementInvalid
      # Table doesn't exist yet (pre-migration boot). Skip silently.
    end

    private

    def build_query_class
      return nil if data_kind == "config_only"
      qdef = parsed_query_definition
      Class.new(::Tiler::Query::Base) do
        define_method(:call) do
          source_slug   = qdef["source_slug"]
          value_column  = qdef["value_column"]
          aggregation   = qdef["aggregation"]
          group_by      = qdef["group_by"]
          source = source_slug && ::Tiler::DataSource.find_by(slug: source_slug)
          if source.nil?
            { value: nil, items: [], error: "data source not found" }
          elsif group_by.present? && safe_col?(group_by)
            scope_for = lambda do |g|
              source.data_records
                    .then { |s| time_window_start ? s.where("recorded_at >= ?", time_window_start) : s }
                    .where("json_extract(payload, ?) = ?", "$.#{group_by}", g.to_s)
            end
            items = source.data_records
                          .where("json_extract(payload, '$.#{group_by}') IS NOT NULL")
                          .distinct
                          .pluck(Arel.sql("json_extract(payload, '$.#{group_by}')"))
                          .compact
                          .map { |g| { label: g, value: aggregate(scope_for.call(g), value_column, aggregation) } }
            { value: nil, items: items }
          else
            scope = source.data_records
                          .then { |s| time_window_start ? s.where("recorded_at >= ?", time_window_start) : s }
            { value: aggregate(scope, value_column, aggregation), items: [] }
          end
        end
      end
    end

    def liquid_panel(panel)
      return {} unless panel
      {
        "id"          => panel.id,
        "title"       => panel.title.to_s,
        "widget_type" => panel.widget_type.to_s,
        "width"       => panel.width,
        "height"      => panel.height
      }
    end

    def stringify(obj)
      case obj
      when Hash  then obj.transform_keys(&:to_s).transform_values { |v| stringify(v) }
      when Array then obj.map { |v| stringify(v) }
      else obj
      end
    end

    def query_definition_must_be_safe
      return if query_definition.blank?
      qdef = parsed_query_definition
      return errors.add(:query_definition, "must be a JSON object") unless qdef.is_a?(Hash)
      qdef.slice("group_by", "value_column").each do |key, val|
        next if val.blank?
        next if val.is_a?(String) && val.match?(/\A[a-zA-Z0-9_]+\z/)
        errors.add(:query_definition, "#{key} must be alphanumeric/underscore")
      end
      if qdef["aggregation"].present? && !AGGS.include?(qdef["aggregation"].to_s)
        errors.add(:query_definition, "aggregation must be one of #{AGGS.join('/')}")
      end
    end

    def template_must_parse
      Liquid::Template.parse(template.to_s, error_mode: :strict)
    rescue Liquid::Error => e
      errors.add(:template, "Liquid parse error: #{e.message}")
    end
  end
end
