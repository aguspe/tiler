module Tiler
  class SettingsController < ApplicationController
    before_action :tiler_authorize_view!

    def show
      @dashboards = Dashboard.by_name
    end
  end
end
