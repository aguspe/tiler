module Tiler
  # Tiler Presets — pre-built dashboards you can drop into a fresh Rails app.
  # Each preset creates the data source(s), the dashboard, every panel with a
  # sensible config, and a small batch of sample records so the visualizations
  # have something to render. Idempotent: re-running a preset reuses existing
  # records by slug.
  #
  # Invoked via the rake CLI:
  #   bin/rails tiler:preset:default
  #   bin/rails tiler:preset:test_automation
  #   bin/rails tiler:preset:commerce
  #   bin/rails tiler:preset           # lists what's available
  module Presets
    REGISTRY = {}

    def self.register(name, klass)
      REGISTRY[name.to_s] = klass
    end

    def self.names
      REGISTRY.keys.sort
    end

    def self.fetch(name)
      REGISTRY.fetch(name.to_s) do
        raise ArgumentError, "unknown preset '#{name}' — try one of: #{names.join(', ')}"
      end
    end

    def self.run!(name)
      preset = fetch(name).new
      preset.build!
      preset
    end

    # Base class — common helpers for building a data source, a dashboard,
    # and seeding sample records. Subclasses define `slug`, `name`, `description`,
    # `data_sources!`, `panels!`, and `sample_records!`.
    class Base
      def slug;        raise NotImplementedError; end
      def name;        raise NotImplementedError; end
      def description; ""; end

      def build!
        @sources = data_sources!
        @dashboard = upsert_dashboard
        panels!(@dashboard, @sources) if @dashboard.panels.empty?
        sample_records!(@sources)
        announce!
      end

      protected

      def upsert_dashboard
        Tiler::Dashboard.find_or_create_by!(slug: slug) do |d|
          d.name            = name
          d.description     = description
          d.refresh_seconds = 60
        end
      end

      def upsert_source(slug:, name:, description: "", schema: [], ingestion: %w[webhook manual])
        Tiler::DataSource.find_or_create_by!(slug: slug) do |s|
          s.name              = name
          s.description       = description
          s.active            = true
          s.schema_definition = schema.to_json
          s.ingestion_methods = ingestion.to_json
        end
      end

      def add_panel(dash, attrs)
        dash.panels.create!(attrs.merge(config: attrs.fetch(:config, {}).to_json))
      end

      def seed!(source, payloads, spread: 7.days)
        return if source.data_records.count >= payloads.size
        payloads.each do |payload|
          source.data_records.create!(
            payload:      payload.to_json,
            recorded_at:  rand(spread).seconds.ago,
            ingested_via: "manual"
          )
        end
      end

      def announce!
        puts "Tiler preset '#{slug}' ready. Visit /tiler/dashboards/#{slug}"
      end
    end
  end
end

require "tiler/presets/default"
require "tiler/presets/test_automation"
require "tiler/presets/commerce"
