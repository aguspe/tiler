module Tiler
  class Dashboard < ApplicationRecord
    self.table_name = "tiler_dashboards"

    has_many :panels, -> { layout_order }, class_name: "Tiler::Panel",
             foreign_key: :tiler_dashboard_id, dependent: :destroy

    REFRESH_OPTIONS = {
      0   => "No auto-refresh",
      30  => "Every 30 seconds",
      60  => "Every minute",
      300 => "Every 5 minutes"
    }.freeze

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validates :slug, presence: true,
                     format: { with: /\A[a-z0-9_-]+\z/ },
                     uniqueness: true
    validates :refresh_seconds, inclusion: { in: REFRESH_OPTIONS.keys }

    before_validation :generate_slug, if: -> { slug.blank? && name.present? }

    scope :by_name, -> { order(:name) }

    def to_param
      slug
    end

    private

    def generate_slug
      self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end
  end
end
