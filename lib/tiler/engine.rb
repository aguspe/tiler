require "turbo-rails"
require "stimulus-rails"

module Tiler
  class Engine < ::Rails::Engine
    isolate_namespace Tiler

    config.generators do |g|
      g.test_framework :minitest
      g.fixture_replacement nil
      g.orm :active_record
    end

    initializer "tiler.register_builtin_widgets" do
      require "tiler/widgets/metric"
      require "tiler/widgets/table"
      require "tiler/widgets/line_chart"
      require "tiler/widgets/bar_chart"
      require "tiler/widgets/pie_chart"
      require "tiler/widgets/status_grid"
    end

    initializer "tiler.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets/stylesheets")
        app.config.assets.precompile += %w[tiler/application.css]
      end
    end
  end
end
