Tiler.configure do |config|
  # Parent controller for all Tiler controllers — inherits your auth, layouts,
  # before_actions, and helpers. Default: "::ApplicationController".
  config.parent_controller = "::ApplicationController"

  # View permission. Receives the controller instance — call any helper your
  # ApplicationController exposes. Default: open access.
  config.authorize_view = ->(ctrl) { ctrl.send(:user_signed_in?) }

  # Manage permission (create/edit/delete dashboards & panels).
  config.authorize_manage = ->(ctrl) { ctrl.send(:current_user)&.admin? }

  # Default polling refresh for dashboards (seconds). Per-dashboard override
  # available via Tiler::Dashboard#refresh_seconds.
  config.default_refresh_seconds = 60

  # Eager-load panel turbo-frames in test env so Capybara/Selenium/Playwright
  # don't race intersection-observer. Defaults to false.
  config.eager_panel_load = Rails.env.test?

  # Optional: layout to wrap Tiler views. Defaults to engine's own minimal layout.
  # config.layout = "application"
end

# Register a custom widget (uncomment + adapt):
#
# Tiler.register_widget(:sparkline,
#   label:   "Sparkline",
#   partial: "my_app/widgets/sparkline",
#   query:   MyApp::Widgets::SparklineQuery)
