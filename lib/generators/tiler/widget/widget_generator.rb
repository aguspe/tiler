require "rails/generators/base"

module Tiler
  module Generators
    class WidgetGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Scaffold a Tiler widget (class, partial, registration snippet)."

      class_option :query, type: :boolean, default: true,
                           desc: "Generate a Tiler::Query::Base subclass"

      def create_widget_class
        template "widget.rb.tt", File.join("app/widgets/tiler", "#{file_name}_widget.rb")
      end

      def create_partial
        template "widget.html.erb.tt", File.join("app/views/tiler/widgets", "_#{file_name}.html.erb")
      end

      def show_next_steps
        say "\nWidget scaffolded.", :green
        say <<~MSG, :cyan
          Files:
            app/widgets/tiler/#{file_name}_widget.rb
            app/views/tiler/widgets/_#{file_name}.html.erb

          The widget self-registers on boot — no initializer edit needed.
          Tiler eager-loads everything under app/widgets/** at startup and
          re-loads on dev change.

          Try it: bin/rails server, then Add Panel -> "#{class_name.titleize}".

          Distributing as a gem? See WIDGETS.md "Packaging widgets as gems".
        MSG
      end

      private

      def file_name
        @_file_name ||= name.underscore
      end

      def class_name
        @_class_name ||= name.camelize
      end
    end
  end
end
