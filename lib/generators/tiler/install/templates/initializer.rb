# Tiler configuration.
# All keys are optional — defaults work out of the box.

Tiler.configure do |config|
  # Inherit from your app's ApplicationController so Tiler shares your auth,
  # before_actions, helpers, and layout if you don't set one below.
  # config.parent_controller = "::ApplicationController"

  # Layout for Tiler pages. Set to false to render Tiler's own layout.
  # config.layout = "application"

  # Authorization hooks. Receive the controller instance.
  # config.authorize_view   = ->(ctrl) { ctrl.send(:user_signed_in?) }
  # config.authorize_manage = ->(ctrl) { ctrl.send(:current_user)&.admin? }
  # config.authorize_ingest = ->(ctrl, source) { true }

  # Webhook ingestion — header name carrying the per-source token.
  # config.webhook_token_header = "X-Tiler-Token"

  # Default dashboard refresh interval.
  # config.default_refresh_seconds = 60
end

# Register a custom widget:
#
# Tiler.register_widget(:sparkline,
#   klass:   MyApp::Widgets::Sparkline,   # or omit to use a partial-only widget
#   label:   "Sparkline",
#   partial: "my_app/widgets/sparkline")
