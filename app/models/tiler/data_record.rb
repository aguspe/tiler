module Tiler
  class DataRecord < ApplicationRecord
    self.table_name = "tiler_data_records"

    belongs_to :data_source, class_name: "Tiler::DataSource",
               foreign_key: :tiler_data_source_id

    INGESTED_VIA = %w[webhook manual csv].freeze

    validates :payload,      presence: true
    validates :recorded_at,  presence: true
    validates :ingested_via, inclusion: { in: INGESTED_VIA }

    before_validation :set_recorded_at

    scope :recent,     ->(n = 100) { order(recorded_at: :desc).limit(n) }
    scope :for_period, ->(from, to) { where(recorded_at: from..to) }

    def parsed_payload
      JSON.parse(payload.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def [](key)
      parsed_payload[key.to_s]
    end

    private

    def set_recorded_at
      self.recorded_at ||= Time.current
    end
  end
end
