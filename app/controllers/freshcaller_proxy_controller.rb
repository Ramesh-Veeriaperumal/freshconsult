class FreshcallerProxyController < ApplicationController
  include Freshcaller::JwtAuthentication

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :authenticated_agent_check
  before_filter :check_freshcaller_account
  before_filter :validate_params, only: [:fetch]
  before_filter :validate_recording_url_params, only: [:recording_url]

  REQUEST_TIMEOUT = 10 #in seconds
  REQUIRED_PARAMS = [:method, :rest_url, :params].freeze

  def fetch
    http_resp = fetch_response(params)
    render http_resp
  end

  def recording_url
    http_resp = fetch_response(method: 'GET', rest_url: "calls/#{params[:call_id]}/recording_url", params: {}.to_json)
    redirect_to JSON.parse(http_resp[:text])['url']
  end

  def fetch_response(request_data)
    domain = current_account.freshcaller_account.domain #nrok.io:port
    response_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[:ok]
    content_type = "application/json"
    accept_type = "application/json"
    response_type = "application/json"
    begin
      method = request_data[:method].downcase
      rest_url = request_data[:rest_url]
      remote_url = "https://"+ domain +  "/" + rest_url
      
      query_params = JSON.parse(request_data[:params])
      query_params['email_id'] = current_user.email.to_s

      options = Hash.new
      options[:headers] = {"Accept" => accept_type, "Content-Type" => content_type, "Authorization" => auth_hash}
      options[:query] = query_params
      options[:timeout] = REQUEST_TIMEOUT
      options[:verify_blacklist] = true
      begin
        # if !Rails.env.development? && Integrations::PROXY_SERVER["host"].present? #host will not be present for layers other than integration layer.
        #   options[:http_proxyaddr] = Integrations::PROXY_SERVER["host"]
        #   options[:http_proxyport] = Integrations::PROXY_SERVER["port"]
        # end
        proxy_request = HTTParty::Request.new("Net::HTTP::#{request_data[:method].to_s.titleize}".constantize, remote_url, options)
        Rails.logger.debug "Sending request: #{proxy_request.inspect}"
        proxy_response = proxy_request.perform
        # Rails.logger.debug "Response Body: #{proxy_response.body}"
        # Rails.logger.debug "Response Code: #{proxy_response.code}"
        Rails.logger.debug "Response Headers: #{proxy_response.headers.inspect}"

        response_body = proxy_response.body
        response_code = proxy_response.code
        response_type = proxy_response.content_type
      rescue Timeout::Error
        Rails.logger.error("Timeout trying to complete the request. \n#{request_data.inspect}")
        response_body = '{"result":"timeout"}'
        response_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[:gateway_timeout]
      rescue => e
        Rails.logger.error("Error during #{method.to_s}ing #{remote_url.to_s}. \n#{e.message}\n#{e.backtrace.join("\n")}")  # TODO make sure any password/apikey sent in the url is not printed here.
        response_body = '{"result":"error"}'
        response_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_gateway]  # Bad Gateway
      end
    rescue => e
      Rails.logger.error("Error while processing proxy request #{request_data.inspect}. \n#{e.message}\n#{e.backtrace.join("\n")}")  # TODO make sure any password/apikey sent in the url is not printed here.
      response_body = '{"result":"error"}'
      response_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[:internal_server_error]
      NewRelic::Agent.notice_error(e)
    end
    response_type = accept_type if response_type.blank?
    return {:text=>response_body, :content_type => response_type, :status => response_code}
  end

  def valid_json?(data)
    begin
      JSON.parse(data)
      return true
    rescue JSON::ParserError => e
      return false
    end
  end
  
  private
    def authenticated_agent_check
      render :json => { error: "unauthorized" }, :status => Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized] if current_user.blank? || !current_user.agent?
    end

    def validate_params
      render :json => {error: "missing parameters" }, :status => Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request] unless params_present?
    end

    def check_freshcaller_account
      render :json => {error: "No Freshcaller account exists" }, :status => Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request] unless current_account.freshcaller_account.present?
    end

    def params_present?
      REQUIRED_PARAMS.all? {|each_param| params.include?(each_param)}
    end

    def validate_recording_url_params
      render json: { error: 'Invalid Recording Url Request' } if params[:call_id].blank? || current_account.freshcaller_calls.recording_with_call_id(params[:call_id]).blank?
    end
end
