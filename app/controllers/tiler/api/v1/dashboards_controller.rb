module Tiler
  module Api
    module V1
      class DashboardsController < ::ActionController::API
        before_action :set_dashboard, only: [ :show, :update, :destroy, :settings ]
        rescue_from ActiveRecord::RecordNotFound do
          render json: { error: "dashboard not found" }, status: :not_found
        end

        def index
          render json: Tiler::Dashboard.by_name.map { |d| serialize(d) }
        end

        def show
          render json: serialize(@dashboard)
        end

        def create
          @dashboard = Tiler::Dashboard.new(dashboard_params)
          if @dashboard.save
            render json: serialize(@dashboard), status: :created
          else
            render json: { errors: @dashboard.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @dashboard.update(dashboard_params)
            render json: serialize(@dashboard)
          else
            render json: { errors: @dashboard.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @dashboard.destroy!
          head :no_content
        end

        # PATCH /tiler/api/v1/dashboards/:id/settings
        # Body: { settings: { tv_mode: true } }
        # Merges into existing settings (does not replace) so callers can
        # ship one key at a time.
        def settings
          incoming = params.require(:settings).permit!.to_h
          merged   = @dashboard.settings_hash.merge(incoming)
          if @dashboard.update(settings: merged.to_json)
            render json: serialize(@dashboard)
          else
            render json: { errors: @dashboard.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_dashboard
          @dashboard = Tiler::Dashboard.find_by!(slug: params[:id])
        end

        def dashboard_params
          params.require(:dashboard).permit(:name, :slug, :description, :refresh_seconds)
        end

        def serialize(dashboard)
          {
            id:              dashboard.id,
            slug:            dashboard.slug,
            name:            dashboard.name,
            description:     dashboard.description,
            refresh_seconds: dashboard.refresh_seconds,
            settings:        dashboard.settings_hash
          }
        end
      end
    end
  end
end
