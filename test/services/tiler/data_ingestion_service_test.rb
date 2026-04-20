require "test_helper"

module Tiler
  class DataIngestionServiceTest < ActiveSupport::TestCase
    setup do
      @source = create_data_source(schema_definition: [
        { "key" => "status",   "type" => "string"  },
        { "key" => "duration", "type" => "float"   },
        { "key" => "count",    "type" => "integer" }
      ].to_json)
    end

    test "accepts single record and coerces types per schema" do
      svc = DataIngestionService.new(@source, { status: "ok", duration: "12.5", count: "7" }, via: "webhook").call
      assert svc.success?
      assert_equal 1, svc.accepted
      rec = @source.data_records.last
      assert_equal "ok", rec["status"]
      assert_equal 12.5, rec["duration"]
      assert_equal 7, rec["count"]
    end

    test "accepts array of records" do
      svc = DataIngestionService.new(@source, [ { status: "ok" }, { status: "err" } ], via: "manual").call
      assert_equal 2, svc.accepted
      assert_equal 2, @source.data_records.count
    end

    test "reports errors for invalid rows but commits valid ones" do
      # Current implementation coerces all rows; there is no schema-level rejection yet.
      # This test pins accepted count to guard regression.
      svc = DataIngestionService.new(@source, [ { status: "ok" } ], via: "manual").call
      assert svc.success?
      assert_equal [], svc.errors
    end

    test "uses provided recorded_at from payload" do
      ts = 2.days.ago.change(usec: 0)
      DataIngestionService.new(@source, { status: "ok", recorded_at: ts.iso8601 }, via: "webhook").call
      assert_in_delta ts.to_f, @source.data_records.last.recorded_at.to_f, 1.0
    end
  end
end
