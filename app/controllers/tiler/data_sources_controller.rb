module Tiler
  class DataSourcesController < ApplicationController
    before_action :tiler_authorize_manage!, except: [ :index, :show ]
    before_action :set_source, only: [ :show, :edit, :update, :destroy ]

    def index
      @data_sources = DataSource.by_name
    end

    def show
      @recent = @data_source.data_records.order(recorded_at: :desc).limit(25)
    end

    def new
      @data_source = DataSource.new(active: true,
                                    ingestion_methods: [ "webhook", "manual" ].to_json)
    end

    def create
      @data_source = DataSource.new(source_params)
      if @data_source.save
        redirect_to data_source_path(@data_source), notice: "Data source created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @data_source.update(source_params)
        redirect_to data_source_path(@data_source), notice: "Data source updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @data_source.destroy!
      redirect_to data_sources_path, notice: "Data source removed."
    end

    private

    def set_source
      @data_source = DataSource.find_by!(slug: params[:id])
    end

    def source_params
      params.require(:data_source).permit(:name, :slug, :description, :active,
                                          :schema_definition, :ingestion_methods)
    end
  end
end
