module Tiler
  class IngestController < ActionController::API
    before_action :set_source
    before_action :authorize_token

    def create
      body = request.body.read
      parsed = body.present? ? JSON.parse(body) : {}
      records = parsed.is_a?(Array) ? parsed : [ parsed ]

      service = DataIngestionService.new(@source, records, via: "webhook")
      service.call

      render json: { accepted: service.accepted, errors: service.errors },
             status: service.success? ? :created : :unprocessable_entity
    rescue JSON::ParserError
      render json: { error: "Invalid JSON" }, status: :bad_request
    end

    private

    def set_source
      @source = DataSource.active.find_by!(slug: params[:source_slug])
    end

    def authorize_token
      header = Tiler.configuration.webhook_token_header
      token  = request.headers[header].presence || params[:token]
      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, @source.webhook_token.to_s)
        render json: { error: "Invalid token" }, status: :unauthorized and return
      end
      return if Tiler.configuration.authorize_ingest.call(self, @source)
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
