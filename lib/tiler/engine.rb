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
      require "tiler/widgets/number_with_delta"
      require "tiler/widgets/table"
      require "tiler/widgets/list"
      require "tiler/widgets/line_chart"
      require "tiler/widgets/bar_chart"
      require "tiler/widgets/pie_chart"
      require "tiler/widgets/status_grid"
      require "tiler/widgets/clock"
      require "tiler/widgets/text"
      require "tiler/widgets/iframe"
      require "tiler/widgets/image"
      require "tiler/widgets/meter"
      require "tiler/widgets/comments"
    end

    initializer "tiler.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets/stylesheets")
        app.config.assets.paths << root.join("app/javascript")
        app.config.assets.precompile += %w[tiler/application.css]
      end
    end

    # Pin the engine's Stimulus controllers into the host app's importmap so
    # the inline IIFEs we replaced (clock, comments rotator, dashboard grid)
    # resolve at runtime. Host apps using importmap will see these controllers
    # under the "controllers/tiler/*" namespace.
    initializer "tiler.importmap", before: "importmap" do |app|
      if app.respond_to?(:config) && app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb") if root.join("config/importmap.rb").exist?
        app.config.importmap.cache_sweepers << root.join("app/javascript/controllers/tiler")
      end
    end
  end
end
