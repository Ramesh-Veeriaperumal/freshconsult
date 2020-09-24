# frozen_string_literal: true

# This is a temporary controller used for proxying api's hit from chat and caller to ocr or mars service based on feature check.
# Will be removed once ocr to mars is fully launched.
module Channel
  class OcrOrMarsProxyController < ApiApplicationController
    include Redis::OthersRedis
    include Redis::RedisKeys
    include ::OmniChannelRouting::Util

    MARS_DOMAINS = %w[mars-us mars-euc mars-au mars-ind].freeze
    TOKEN_REGEX = /Token (.*)/.freeze
    ALLOWED_SERVICES = %w[freshchat freshcaller].freeze
    NEXT_ELIGIBLE_PATH = '/api/v1/agents/next-eligible'.freeze
    FRESHCALLER_SERVICE = 'freshcaller'.freeze
    NAMESPACE = 'api/v1/'.freeze
    OCR_AGENTS = 'ocr_agents'.freeze

    skip_before_filter :check_privilege, :verify_authenticity_token, :check_account_state, :set_current_account, :load_object
    before_filter :validate_domain
    before_filter :validate_jwt_auth

    def execute
      service_response = request_service(@service, request.method.downcase.to_sym, proxy_path, request_params.to_json, proxy_to_mars?, @jwt_token)
      @proxy_response = service_response.body
      response.status = 204 if @proxy_response.empty?
    rescue StandardError => e
      Rails.logger.error "Exception while proxying request to service :: #{e.inspect}"
      NewRelic::Agent.notice_error(e)
      @proxy_response = e.response.body
      response.status = e.response.code
    end

    private

      def validate_domain
        return true unless Rails.env.production?

        unless MARS_DOMAINS.include?(request.domain)
          Rails.logger.error "Request is not allowed for domain #{request.domain}"
          head 404
        end
      end

      def validate_jwt_auth
        auth_token = request.headers['Authorization']
        render_request_error :invalid_credentials, 401 && return if auth_token.nil?
        auth_token = auth_token.match(TOKEN_REGEX)
        render_request_error :invalid_credentials, 401 && return if auth_token.nil? || auth_token.length <= 1
        @jwt_token = auth_token[1].strip
        jwt_payload = @jwt_token.split('.')[1]
        if jwt_payload.blank?
          Rails.logger.error 'JWT payload not present for proxy requests'
          render_request_error :invalid_credentials, 401 && return
        end
        @service = JSON.parse(Base64.decode64(jwt_payload))['service']
        @product_account_id = JSON.parse(Base64.decode64(jwt_payload))['account_id']
        render_request_error :access_denied, 403 unless @service && ALLOWED_SERVICES.include?(@service) && @product_account_id
      end

      def proxy_to_mars?
        @proxy_to_mars ||= (request.path == NEXT_ELIGIBLE_PATH && account_has_agent_statuses_feature?) || account_has_ocr_to_mars_feature? ? true : false
      end

      def account_has_agent_statuses_feature?
        return false unless @service == FRESHCALLER_SERVICE

        ismember?(AGENT_STATUSES_CALLER_ACCOUNT_IDS, @product_account_id)
      end

      def account_has_ocr_to_mars_feature?
        key = @service == FRESHCALLER_SERVICE ? OCR_TO_MARS_CALLER_ACCOUNT_IDS : OCR_TO_MARS_CHAT_ACCOUNT_IDS
        ismember?(key, @product_account_id)
      end

      def request_params
        if get_request?
          {}
        else
          Rails.logger.info("Raw params from chat/caller - #{request.raw_post}")
          JSON.parse(request.raw_post)
        end
      end

      def proxy_path
        path = request.url.split(NAMESPACE)[1]
        if proxy_to_mars?
          path = path.gsub(OCR_AGENTS, 'agents') if path.include?(OCR_AGENTS)
          path = NAMESPACE + path
        end
        path
      end
  end
end
