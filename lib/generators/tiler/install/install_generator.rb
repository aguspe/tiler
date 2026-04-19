require "rails/generators/base"
require "rails/generators/active_record"

module Tiler
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Install Tiler: copies migrations, initializer, and mounts the engine."

      def copy_initializer
        template "initializer.rb", "config/initializers/tiler.rb"
      end

      def copy_migrations
        rake "tiler:install:migrations"
      rescue StandardError
        say_status(:warn, "Could not copy migrations via rake; copying manually.", :yellow)
        migration_template(
          "../../../../../db/migrate/20260419000001_create_tiler_tables.rb",
          "db/migrate/create_tiler_tables.rb"
        )
      end

      def mount_engine
        route %(mount Tiler::Engine => "/tiler", as: :tiler)
      end

      def show_post_install
        say "\nTiler installed.", :green
        say "  1. bin/rails db:migrate"
        say "  2. Visit /tiler in your app"
        say "  3. Edit config/initializers/tiler.rb to plug in auth\n"
      end
    end
  end
end
