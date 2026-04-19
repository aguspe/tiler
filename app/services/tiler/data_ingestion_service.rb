module Tiler
  class DataIngestionService
    attr_reader :accepted, :errors

    def initialize(data_source, records, via:, user: nil)
      @data_source = data_source
      @records     = Array(records)
      @via         = via
      @user        = user
      @accepted    = 0
      @errors      = []
    end

    def call
      ActiveRecord::Base.transaction do
        @records.each_with_index do |raw, i|
          payload = coerce_payload(raw)
          record  = @data_source.data_records.build(
            payload:      payload.to_json,
            recorded_at:  extract_recorded_at(raw) || Time.current,
            source_ref:   raw["source_ref"] || raw[:source_ref],
            ingested_via: @via
          )
          if record.save
            @accepted += 1
          else
            @errors << { index: i, messages: record.errors.full_messages }
          end
        end
      end
      self
    end

    def success?
      @errors.empty?
    end

    private

    def coerce_payload(raw)
      clean = raw.transform_keys(&:to_s).except("source_ref", "recorded_at")
      schema = @data_source.parsed_schema
      return clean if schema.empty?
      schema.each_with_object({}) do |col, out|
        out[col["key"]] = coerce_value(clean[col["key"]], col["type"])
      end
    end

    def coerce_value(value, type)
      return nil if value.nil?
      case type
      when "integer"  then value.to_s.match?(/\A-?\d+\z/) ? value.to_i : nil
      when "float"    then Float(value) rescue nil
      when "boolean"  then ActiveModel::Type::Boolean.new.cast(value)
      when "datetime" then Time.zone.parse(value.to_s) rescue nil
      else value.to_s
      end
    end

    def extract_recorded_at(raw)
      val = raw["recorded_at"] || raw[:recorded_at]
      val.blank? ? nil : (Time.zone.parse(val.to_s) rescue nil)
    end
  end
end
