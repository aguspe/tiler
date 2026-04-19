module Tiler
  class PanelsController < ApplicationController
    before_action :tiler_authorize_manage!, except: [ :preview ]
    before_action :set_dashboard
    before_action :set_panel, only: [ :edit, :update, :destroy, :preview ]

    def new
      @panel = @dashboard.panels.build(col_span: 1, widget_type: Tiler.widgets.types.first)
      @data_sources = DataSource.active.by_name
    end

    def create
      @panel = @dashboard.panels.build(panel_params)
      if @panel.save
        redirect_to dashboard_path(@dashboard), notice: "Panel added."
      else
        @data_sources = DataSource.active.by_name
        render :new, status: :unprocessable_entity
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
      params.require(:panel).permit(:tiler_data_source_id, :title, :widget_type, :col_span, :position, :config)
    end
  end
end
