module Tiler
  class PanelsController < ApplicationController
    before_action :tiler_authorize_manage!, except: [ :preview ]
    before_action :set_dashboard
    before_action :set_panel, only: [ :edit, :update, :destroy, :preview ]

    def new
      next_y = (@dashboard.panels.maximum(:y) || -1) + 1
      requested_type = params.dig(:panel, :widget_type).presence
      widget_type = Tiler.widgets[requested_type] ? requested_type : Tiler.widgets.types.first
      @panel = @dashboard.panels.build(
        width: 6, height: 2, x: 0, y: next_y,
        widget_type: widget_type
      )
      @data_sources = DataSource.active.by_name
    end

    def create
      @panel = @dashboard.panels.build(panel_params)
      if @panel.save
        respond_to do |format|
          format.html         { redirect_to dashboard_path(@dashboard), notice: "Panel added." }
          format.json         { render json: panel_json(@panel), status: :created }
          format.turbo_stream # renders create.turbo_stream.erb (appends to grid)
        end
      else
        respond_to do |format|
          format.html do
            @data_sources = DataSource.active.by_name
            render :new, status: :unprocessable_entity
          end
          format.json { render json: { errors: @panel.errors.full_messages }, status: :unprocessable_entity }
          format.turbo_stream { render json: { errors: @panel.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def edit
      @data_sources = DataSource.active.by_name
    end

    def update
      if @panel.update(panel_params)
        redirect_to dashboard_path(@dashboard), notice: "Panel updated."
      else
        @data_sources = DataSource.active.by_name
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @panel.destroy!
      redirect_to dashboard_path(@dashboard), notice: "Panel removed."
    end

    def preview
      @data = @panel.data
      render partial: "tiler/panels/panel", locals: { panel: @panel, data: @data }
    end

    private

    def set_dashboard
      @dashboard = Dashboard.find_by!(slug: params[:dashboard_id])
    end

    def set_panel
      @panel = @dashboard.panels.find(params[:id])
    end

    def panel_params
      params.require(:panel).permit(:tiler_data_source_id, :title, :widget_type,
                                    :width, :height, :x, :y, :config)
    end

    def panel_json(panel)
      {
        id:            panel.id,
        widget_type:   panel.widget_type,
        title:         panel.title,
        x:             panel.x,
        y:             panel.y,
        width:         panel.width,
        height:        panel.height,
        config:        panel.config,
        preview_url:   preview_dashboard_panel_path(@dashboard, panel)
      }
    end
  end
end
