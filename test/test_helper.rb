ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"

# Engine bin/rails fires the engine railtie which auto-appends the engine's
# db/migrate path. The dummy app's zz_dedupe_engine_migrations initializer
# also adds it (covering the bundle-exec-from-dummy case). Without an explicit
# dedupe before maintain_test_schema! runs, the duplicate path makes
# `assume_migrated_upto_version` see each migration twice and abort.
paths = Rails.application.config.paths["db/migrate"]
list  = paths.to_a.uniq
paths.instance_variable_set(:@paths, list)

ActiveRecord::Migration.maintain_test_schema!

if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
end

module TilerTestHelpers
  def create_data_source(attrs = {})
    Tiler::DataSource.create!({
      name: "Source #{SecureRandom.hex(3)}",
      schema_definition: [ { "key" => "status", "type" => "string" },
                           { "key" => "duration", "type" => "float" } ].to_json,
      ingestion_methods: [ "webhook", "manual" ].to_json,
      active: true
    }.merge(attrs))
  end

  def create_dashboard(attrs = {})
    Tiler::Dashboard.create!({ name: "Dashboard #{SecureRandom.hex(3)}" }.merge(attrs))
  end

  def create_panel(dashboard, attrs = {})
    dashboard.panels.create!({
      title: "Panel #{SecureRandom.hex(3)}",
      widget_type: "metric",
      width: 6, height: 2, x: 0, y: 0
    }.merge(attrs))
  end

  def create_record(source, payload, recorded_at: Time.current, via: "manual")
    source.data_records.create!(
      payload: payload.to_json, recorded_at: recorded_at, ingested_via: via
    )
  end
end

class ActiveSupport::TestCase
  include TilerTestHelpers
end
