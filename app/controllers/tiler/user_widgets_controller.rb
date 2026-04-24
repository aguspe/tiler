module Tiler
  # CRUD for runtime user-defined (Liquid) widgets. Lives under /settings/user_widgets
  # so it's discoverable from the Settings page.
  class UserWidgetsController < ApplicationController
    before_action :tiler_authorize_view!
    before_action :set_user_widget, only: [ :edit, :update, :destroy ]

    def index
      @user_widgets = UserWidget.order(:slug)
    end

    def new
      @user_widget = UserWidget.new(default_w: 4, default_h: 3,
                                    template: default_template_seed)
    end

    def create
      @user_widget = UserWidget.new(user_widget_params)
      if @user_widget.save
        redirect_to user_widgets_path, notice: "Custom widget '#{@user_widget.slug}' created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @user_widget.update(user_widget_params)
        redirect_to user_widgets_path, notice: "Custom widget '#{@user_widget.slug}' updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      slug = @user_widget.slug
      @user_widget.destroy!
      redirect_to user_widgets_path, notice: "Custom widget '#{slug}' deleted."
    end

    # POST /settings/user_widgets/preview
    # Body: { template, sample_data } — returns the rendered HTML so the form
    # can show a live preview without saving.
    def preview
      template = params[:template].to_s.first(UserWidget::TEMPLATE_MAX)
      sample   = JSON.parse(params[:sample_data].to_s.presence || "{}") rescue {}
      tpl = ::Liquid::Template.parse(template, error_mode: :strict)
      render plain: tpl.render!("data" => sample, "panel" => { "title" => "Preview" }, "config" => {})
    rescue ::Liquid::Error => e
      render plain: "Liquid error: #{e.message}", status: :unprocessable_entity
    end

    private

    def set_user_widget
      @user_widget = UserWidget.find(params[:id])
    end

    def user_widget_params
      params.require(:user_widget).permit(
        :slug, :label, :template, :data_kind,
        :query_definition, :default_config,
        :default_w, :default_h
      )
    end

    def default_template_seed
      <<~LIQUID
        <div class="tiler-metric">
          <div class="tiler-metric-value">{{ data.value | default: "—" }}</div>
          <div class="tiler-metric-label">{{ panel.title }}</div>
        </div>
      LIQUID
    end
  end
end
