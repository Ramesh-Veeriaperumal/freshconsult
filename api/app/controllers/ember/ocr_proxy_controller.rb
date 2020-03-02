module Ember
  class OcrProxyController < ApiApplicationController

    include Fdadmin::ApiCallConstants
    skip_before_filter :load_object

    ADMINSERVICE = 'admin'.freeze

    def execute
      begin
        options = Hash.new
        options[:headers] = headers
        options[:body] = params.except(:version, :format, :controller, :action, :ocr_proxy).to_json
        options[:verify_blacklist] = true
        net_http_method = HTTP_METHOD_TO_CLASS_MAPPING[request_method.downcase.to_sym]
        url = OCR_CONFIG[:api_endpoint] + request.url.split("ocr_proxy/").last
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
        account_id = Account.current.account_additional_settings.additional_settings[:ocr_account_id].to_s
        payload = { service: ADMINSERVICE, account_id: account_id, actor: User.current.try(:id).to_s }
        jwt_token = construct_jwt_token(payload)

        { 
          'Authorization' => "Token #{jwt_token}",
          'Content-Type'  => 'application/json',
          'X-Request-ID'  => "#{Thread.current[:message_uuid]}"
        }
      end

      def construct_jwt_token(payload)
        JWT.encode payload, OCR_CONFIG[:admin_jwt_secret], 'HS256', { "alg": "HS256", "typ": "JWT" }
      end

      def request_method
        request.request_method
      end

  end
end
