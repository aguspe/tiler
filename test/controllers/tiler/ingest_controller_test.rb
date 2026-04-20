require "test_helper"

module Tiler
  class IngestControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @source = create_data_source(ingestion_methods: [ "webhook" ].to_json)
    end

    test "POST without token returns 401" do
      post ingest_path(source_slug: @source.slug),
           params: { status: "ok" }.to_json,
           headers: { "Content-Type" => "application/json" }
      assert_response :unauthorized
    end

    test "POST with wrong token returns 401" do
      post ingest_path(source_slug: @source.slug),
           params: { status: "ok" }.to_json,
           headers: {
             "Content-Type" => "application/json",
             "X-Tiler-Token" => "bogus"
           }
      assert_response :unauthorized
    end

    test "POST with valid token creates record" do
      assert_difference "@source.data_records.count", 1 do
        post ingest_path(source_slug: @source.slug),
             params: { status: "ok", duration: 42.5 }.to_json,
             headers: {
               "Content-Type" => "application/json",
               "X-Tiler-Token" => @source.webhook_token
             }
      end
      assert_response :created
      assert_equal({ "accepted" => 1, "errors" => [] }, JSON.parse(@response.body))
    end

    test "POST array batch" do
      assert_difference "@source.data_records.count", 3 do
        post ingest_path(source_slug: @source.slug),
             params: [ { status: "ok" }, { status: "ok" }, { status: "err" } ].to_json,
             headers: {
               "Content-Type" => "application/json",
               "X-Tiler-Token" => @source.webhook_token
             }
      end
    end

    test "POST invalid JSON returns 400" do
      post ingest_path(source_slug: @source.slug),
           params: "{not-json",
           headers: {
             "Content-Type" => "application/json",
             "X-Tiler-Token" => @source.webhook_token
           }
      assert_response :bad_request
    end

    test "POST to unknown source returns 404" do
      post ingest_path(source_slug: "does_not_exist"),
           params: "{}",
           headers: {
             "Content-Type" => "application/json",
             "X-Tiler-Token" => "any"
           }
      assert_response :not_found
    end
  end
end
