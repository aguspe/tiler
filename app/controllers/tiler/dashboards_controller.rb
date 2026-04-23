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
      items = params[:items]
      unless items.is_a?(Array)
        return render json: { error: "items must be an array" }, status: :bad_request
      end

      applied = 0
      skipped = 0

      ActiveRecord::Base.transaction do
        items.each do |item|
          unless item.respond_to?(:[]) &&
                 item[:id].present? &&
                 !item[:x].nil? && !item[:y].nil? &&
                 !item[:w].nil? && !item[:h].nil?
            skipped += 1
            next
          end

          panel = @dashboard.panels.find_by(id: item[:id])
          unless panel
            skipped += 1
            next
          end

          x = item[:x].to_i.clamp(0, 11)
          y = [ item[:y].to_i, 0 ].max
          w = item[:w].to_i.clamp(1, 12)
          h = item[:h].to_i.clamp(1, 12)
          panel.update_columns(x: x, y: y, width: w, height: h)
          applied += 1
        end
      end

      # update_columns bypasses callbacks → Panel#broadcasts_to does NOT fire.
      # Trigger a single morph-style refresh so other dashboard viewers pick up
      # the new layout. Uses turbo-rails' broadcast_refresh_to (Turbo 8 morph).
      if applied.positive?
        Turbo::StreamsChannel.broadcast_refresh_to(@dashboard)
      end

      render json: { applied: applied, skipped: skipped }, status: :ok
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
