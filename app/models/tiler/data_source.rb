module Tiler
  class DataSource < ApplicationRecord
    self.table_name = "tiler_data_sources"

    has_many :data_records, class_name: "Tiler::DataRecord",
             foreign_key: :tiler_data_source_id, dependent: :destroy
    has_many :panels, class_name: "Tiler::Panel",
             foreign_key: :tiler_data_source_id, dependent: :nullify

    INGESTION_METHODS = %w[webhook manual csv].freeze
    COLUMN_TYPES      = %w[string integer float boolean datetime enum].freeze

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validates :slug, presence: true,
                     format: { with: /\A[a-z0-9_]+\z/, message: "lowercase letters, numbers, underscores only" },
                     uniqueness: true

    before_validation :generate_slug, if: -> { slug.blank? && name.present? }
    before_create     :generate_webhook_token, if: :webhook_enabled?

    scope :active,  -> { where(active: true) }
    scope :by_name, -> { order(:name) }

    def parsed_schema
      JSON.parse(schema_definition.presence || "[]")
    rescue JSON::ParserError
      []
    end

    def parsed_ingestion_methods
      JSON.parse(ingestion_methods.presence || "[]")
    rescue JSON::ParserError
      []
    end

    def schema_column_keys
      parsed_schema.map { |c| c["key"] }
    end

    def webhook_enabled?
      parsed_ingestion_methods.include?("webhook")
    end

    def regenerate_webhook_token!
      update!(webhook_token: SecureRandom.urlsafe_base64(32))
    end

    def to_param
      slug
    end

    private

    def generate_slug
      self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")
    end

    def generate_webhook_token
      self.webhook_token ||= SecureRandom.urlsafe_base64(32)
    end
  end
end
