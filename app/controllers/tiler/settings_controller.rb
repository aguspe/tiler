module Tiler
  class SettingsController < ApplicationController
    before_action :tiler_authorize_view!

    def show
      @dashboards = Dashboard.by_name
      @last_dashboard = pick_last_dashboard
    end

    private

    # Choose which dashboard the "Back" link should point at:
    #   1. Whatever the user was last viewing (session-tracked).
    #   2. Failing that, the only dashboard if there's just one.
    #   3. Failing that, the alphabetically-first dashboard.
    #   4. nil if no dashboards exist (Settings page hides the back link).
    def pick_last_dashboard
      slug = session[:tiler_last_dashboard_slug]
      return @dashboards.find { |d| d.slug == slug } if slug.present?
      @dashboards.first
    end
  end
end
