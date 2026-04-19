module Tiler
  class Configuration
    attr_accessor :parent_controller,
                  :layout,
                  :authorize_view,
                  :authorize_manage,
                  :authorize_ingest,
                  :current_user_method,
                  :webhook_token_header,
                  :default_refresh_seconds

    def initialize
      @parent_controller       = "::ApplicationController"
      @layout                  = "tiler/application"
      @authorize_view          = ->(_ctrl) { true }
      @authorize_manage        = ->(_ctrl) { true }
      @authorize_ingest        = ->(_ctrl, _source) { true }
      @current_user_method     = :current_user
      @webhook_token_header    = "X-Tiler-Token"
      @default_refresh_seconds = 0
    end
  end
end
