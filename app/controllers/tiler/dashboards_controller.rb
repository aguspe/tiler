module Tiler
  class DashboardsController < ApplicationController
    before_action :tiler_authorize_manage!, only: [ :new, :create, :edit, :update, :destroy, :layout ]
    before_action :set_dashboard, only: [ :show, :edit, :update, :destroy, :layout ]

    def index
      @dashboards = Dashboard.by_name
    end

    def show
    end

    def new
      @dashboard = Dashboard.new(refresh_seconds: Tiler.configuration.default_refresh_seconds)
    end

    def create
      @dashboard = Dashboard.new(dashboard_params)
      if @dashboard.save
        redirect_to dashboard_path(@dashboard), notice: "Dashboard created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @dashboard.update(dashboard_params)
        redirect_to dashboard_path(@dashboard), notice: "Dashboard updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @dashboard.destroy!
      redirect_to dashboards_path, notice: "Dashboard deleted."
    end

    def layout
      items = Array(params[:items])
      ActiveRecord::Base.transaction do
        items.each do |item|
          panel = @dashboard.panels.find_by(id: item[:id])
          next unless panel
          panel.update_columns(
            x:      item[:x].to_i,
            y:      item[:y].to_i,
            width:  item[:w].to_i.clamp(1, 12),
            height: item[:h].to_i.clamp(1, 12)
          )
        end
      end
      head :ok
    end

    private

    def set_dashboard
      @dashboard = Dashboard.find_by!(slug: params[:id])
    end

    def dashboard_params
      params.require(:dashboard).permit(:name, :slug, :description, :refresh_seconds)
    end
  end
end
