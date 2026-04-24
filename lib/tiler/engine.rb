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

    # Pick up host-app widget definitions from app/widgets/**/*.rb. Each file
    # is expected to define a Tiler::Widget subclass and call
    # Tiler.widgets.register("type", klass: ...). Loaded eagerly so the
    # registry is populated before the first request — Zeitwerk's lazy
    # autoload would otherwise skip files that aren't referenced.
    #
    # Custom widgets distributed as gems should require their files in the
    # gem's own railtie/engine; the registry is global.
    initializer "tiler.host_widgets", after: :load_config_initializers do |app|
      paths = [
        app.root.join("app/widgets/**/*.rb"),
        app.root.join("app/widgets/tiler/**/*.rb")
      ]
      paths.each do |glob|
        Dir.glob(glob).sort.each { |f| require f }
      end
    end

    # Re-require host widgets on dev reload so editing app/widgets/foo_widget.rb
    # updates the registry without restarting the server.
    initializer "tiler.host_widgets_reloader" do |app|
      next unless app.config.respond_to?(:reload_classes_only_on_change)
      app.config.to_prepare do
        host_root = app.root.join("app/widgets")
        next unless host_root.exist?
        Dir.glob(host_root.join("**/*.rb")).sort.each { |f| load f }
      end
    end

    # Runtime user-defined widgets (no-code, Liquid). Each row in
    # tiler_user_widgets gets registered as an anonymous Widget subclass
    # under "user_<slug>". Wrapped in a to_prepare so dev reloads pick up
    # any new rows added since the previous request.
    initializer "tiler.user_widgets" do |app|
      app.config.to_prepare do
        if defined?(::Tiler::UserWidget) && ::ActiveRecord::Base.connection_pool.with_connection { ::ActiveRecord::Base.connection.data_source_exists?("tiler_user_widgets") }
          ::Tiler::UserWidget.register_all!
        end
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
        # Booting before the DB is reachable (rake tasks, asset precompile).
      end
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
