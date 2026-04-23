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

    # Per-dashboard settings stored as a JSON text column. Today: { tv_mode }.
    # Returns the parsed Hash; safe even when the column is nil/blank.
    def settings_hash
      JSON.parse(settings.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def tv_mode?
      !!settings_hash["tv_mode"]
    end

    # Personalization (per-dashboard, persisted in settings JSON):
    #   background_color: "#rrggbb" / "#rgb" — applied to the dashboard's
    #   --paper token via inline style. Invalid input returns nil so the
    #   layout falls back to the design system default.
    HEX_COLOR_RE = /\A#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\z/i

    def background_color
      c = settings_hash["background_color"].to_s.strip
      c.match?(HEX_COLOR_RE) ? c : nil
    end

    # logo_url: http(s) URL only — rejected when scheme is anything else
    # (javascript:, data:, file:, etc.) so we never render an unsafe <img src>.
    def logo_url
      u = settings_hash["logo_url"].to_s.strip
      return nil if u.empty?
      prefix = u[0, 8].downcase
      (prefix.start_with?("http://") || prefix.start_with?("https://")) ? u : nil
    end

    private

    def generate_slug
      self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end
  end
end
