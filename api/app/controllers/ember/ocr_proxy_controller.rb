module Ember
  class OcrProxyController < ApiApplicationController

    include Fdadmin::ApiCallConstants
    include OmniChannelRouting::Constants
    skip_before_filter :load_object

    def execute
      begin
        options = Hash.new
        options[:headers] = headers
        options[:body] = params.except(:version, :format, :controller, :action, :ocr_proxy).to_json
        options[:verify_blacklist] = true
        net_http_method = HTTP_METHOD_TO_CLASS_MAPPING[request_method.downcase.to_sym]
        url = OCR_BASE_URL + request.url.split('ocr_proxy/').last
        proxy_request = HTTParty::Request.new(net_http_method, url, options)
        Rails.logger.debug "Sending request: #{proxy_request.inspect}"
        proxy_response = proxy_request.perform
        Rails.logger.debug "Response: #{proxy_response.inspect}"

        @proxy_response = proxy_response.parsed_response
      rescue => e
        @proxy_response = proxy_response.parsed_response
        Rails.logger.error("Error while processing proxy request :: #{e.message} :: #{e.backtrace[0..10].inspect}")
        NewRelic::Agent.notice_error(e)
      end
      render "#{controller_path}/execute", status: proxy_response.code
    end 

    def invalid_endpoint_error
      render_request_error :invalid_endpoint, 401
      nil
    end

    private

      def headers
        {
          'Authorization' => "Token #{construct_jwt_token}",
          'Content-Type'  => 'application/json',
          'X-Request-ID'  => "#{Thread.current[:message_uuid]}"
        }
      end

      def construct_jwt_token
        client_service = :admin
        jwt_payload = {
          account_id: Account.current.ocr_account_id.to_s,
          service: OCR_CLIENT_SERVICES[client_service],
          actor: User.current.try(:id).to_s
        }
        JWT.encode(
          jwt_payload,
          OCR_CLIENT_SECRET_KEYS[client_service],
          OCR_JWT_SIGNING_ALG,
          OCR_JWT_HEADER
        )
      end

      def request_method
        request.request_method
      end

  end
end
