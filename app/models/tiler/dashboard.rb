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

    # Theme — per-dashboard CSS token overrides stored in settings JSON.
    # Each accessor returns a validated hex color string or nil (so the
    # design-system default applies). Tokens are emitted as inline style on
    # the .tiler-dashboard wrapper so descendants inherit naturally.
    #
    #   page_bg        -> --paper   (page background)
    #   tile_bg        -> --paper-2 (panel surface)
    #   tile_header_bg -> --paper-3 (panel header strip)
    #   gutter_bg      -> --border  (grid gutters)
    HEX_COLOR_RE = /\A#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\z/i
    THEME_KEYS = %w[page_bg tile_bg tile_header_bg gutter_bg].freeze

    def page_bg;        theme_color("page_bg");        end
    def tile_bg;        theme_color("tile_bg");        end
    def tile_header_bg; theme_color("tile_header_bg"); end
    def gutter_bg;      theme_color("gutter_bg");      end

    # Returns { token => hex } for every set theme key, ready to splat into
    # an inline style attribute. Empty hash when nothing is themed.
    def theme_inline_style
      mapping = { "page_bg" => "--paper", "tile_bg" => "--paper-2",
                  "tile_header_bg" => "--paper-3", "gutter_bg" => "--border" }
      pairs = THEME_KEYS.filter_map do |key|
        v = theme_color(key)
        v ? "#{mapping[key]}: #{v};" : nil
      end
      pairs.join(" ")
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

    def theme_color(key)
      c = settings_hash[key].to_s.strip
      c.match?(HEX_COLOR_RE) ? c : nil
    end

    def generate_slug
      self.slug = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end
  end
end
