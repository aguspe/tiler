module Tiler
  class ApplicationController < Tiler.configuration.parent_controller.constantize
    layout Tiler.configuration.layout

    helper_method :tiler_authorize_view!, :tiler_authorize_manage!

    before_action :tiler_authorize_view!

    private

    def tiler_authorize_view!
      return if instance_exec(self, &Tiler.configuration.authorize_view)
      head :forbidden
    end

    def tiler_authorize_manage!
      return if instance_exec(self, &Tiler.configuration.authorize_manage)
      redirect_back_or_to(dashboards_path, alert: "Access denied.")
    end
  end
end
