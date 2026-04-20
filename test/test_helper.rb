ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"

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
