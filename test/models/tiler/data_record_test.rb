require "test_helper"

module Tiler
  class DataRecordTest < ActiveSupport::TestCase
    setup { @source = create_data_source }

    test "requires payload, ingested_via, recorded_at" do
      r = DataRecord.new(data_source: @source)
      refute r.valid?
      assert_includes r.errors[:payload], "can't be blank"
    end

    test "sets recorded_at to now by default" do
      freeze_time = Time.current
      travel_to freeze_time do
        r = @source.data_records.create!(payload: { a: 1 }.to_json, ingested_via: "manual")
        assert_in_delta freeze_time.to_f, r.recorded_at.to_f, 1.0
      end
    end

    test "parsed_payload returns hash" do
      r = create_record(@source, { status: "ok", n: 42 })
      assert_equal "ok", r["status"]
      assert_equal 42, r.parsed_payload["n"]
    end

    test "rejects unknown ingested_via" do
      r = DataRecord.new(data_source: @source, payload: "{}", ingested_via: "trumpet")
      refute r.valid?
    end
  end
end
