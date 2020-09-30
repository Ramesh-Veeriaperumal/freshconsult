# frozen_string_literal: true

module ChannelIntegrations::Multiplexer
  module MessageService
    include Iam::AuthToken
    MULTIPLEXER_MESSAGE_API_PATH = '/api/v2/channels/%{channel_id}/messages'.freeze
    TIMEOUT_IN_SEC = 3

    def post_message(user, params)
      response = multiplexer.post do |req|
        req.url format(MULTIPLEXER_MESSAGE_API_PATH, channel_id: params[:channel_id])
        req.headers['Content-Type'] = 'application/json'
        req.headers['Authorization'] = construct_jwt_with_bearer(user)
        req.body = payload(params)
        req.options.timeout = TIMEOUT_IN_SEC
      end
      Rails.logger.info "Multiplexer response status:#{response.status}, body:#{response.body.try(:inspect)}"
    end

    def multiplexer
      Faraday.new(AppConfig['microservices']['internal_endpoint']) do |faraday|
        faraday.request(:retry, max: 3, interval: 1, backoff_factor: 2)
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
      end
    end

    def payload(params)
      {
        profile_unique_id: params[:profile_unique_id],
        body: params[:body]
      }.to_json
    end
  end
end
