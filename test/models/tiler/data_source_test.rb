require "test_helper"

module Tiler
  class DataSourceTest < ActiveSupport::TestCase
    test "auto-generates slug" do
      s = DataSource.create!(name: "Nightly Builds")
      assert_equal "nightly_builds", s.slug
    end

    test "generates webhook_token when webhook enabled" do
      s = create_data_source(ingestion_methods: [ "webhook" ].to_json)
      assert s.webhook_token.present?
      assert s.webhook_enabled?
    end

    test "does not generate webhook_token when webhook disabled" do
      s = create_data_source(ingestion_methods: [ "manual" ].to_json)
      assert_nil s.webhook_token
      refute s.webhook_enabled?
    end

    test "regenerate_webhook_token! rotates the token" do
      s = create_data_source(ingestion_methods: [ "webhook" ].to_json)
      old = s.webhook_token
      s.regenerate_webhook_token!
      refute_equal old, s.reload.webhook_token
    end

    test "parsed_schema returns [] on bad JSON" do
      s = create_data_source(schema_definition: "not-json")
      assert_equal [], s.parsed_schema
    end

    test "schema_column_keys extracts keys from schema" do
      s = create_data_source(schema_definition: [
        { "key" => "a", "type" => "string" },
        { "key" => "b", "type" => "float" }
      ].to_json)
      assert_equal %w[a b], s.schema_column_keys
    end

    test "slug must be lowercase with underscores only" do
      s = DataSource.new(name: "X", slug: "BAD-SLUG")
      refute s.valid?
    end
  end
end
