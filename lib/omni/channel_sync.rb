# frozen_string_literal: true

# Abstract class
class Omni::ChannelSync
  OMNI_REQUEST_FAILED = 'OMNI_REQUEST_FAILED'
  attr_accessor :resource_id, :action, :channel, :method, :params, :performed_by_id, :response, :response_success, :response_code,
                :response_error_message, :suppress_failure, :custom_headers, :response_headers, :resource_type, :response_body
  attr_reader :client_id, :authorization_token

  ACTION_MAPPING = {
    create: :post,
    update: :put,
    delete: :delete,
    get: :get,
    feature_toggle: :put
  }.freeze

  SUCCESS_CODES = (200..204).freeze
  SERVICE_UNAVAILABLE_CODES = (500..504).to_a.freeze

  def initialize(args)
    %i[action channel resource_id params performed_by_id resource_type].each { |name| safe_send("#{name}=", args[name.to_sym]) }
    self.method = ACTION_MAPPING[action.to_sym]
    self.custom_headers = args[:headers] || {}
    self.params = args[:params] || {}
  end

  def get(path, query_params = nil)
    http_connection.get(path) do |request|
      request.headers = headers
      request.params = query_params
      Rails.logger.info "#{klass_name} Request:: #{request.inspect} for Account #{current_account.id}"
    end
  end

  def post(path, body_params = nil)
    http_connection.post(path) do |request|
      request.headers = headers
      request.body = body_params.to_json
      Rails.logger.info "#{klass_name} Request:: #{request.inspect} for Account #{current_account.id}"
    end
  end

  def put(path, body_params = nil)
    http_connection.put(path) do |request|
      request.headers = headers
      request.body = body_params.to_json
      Rails.logger.info "#{klass_name} Request:: #{request.inspect} for Account #{current_account.id}"
    end
  end

  def sync_channel
    raw_response = send_request_with_logs
    parse_response(raw_response)
  end

  # Needs to be defined in the child
  # # The child class should define this to parse the response object
  # # Attributes response_success, response_code, response_error_message, response should be set in this method
  # End
  def parse_response(response)
    self.response = response
    self.response_code = response.status
    self.response_headers = response.headers
    self.response_body = response.body
    self.response_success = response.success?
    Rails.logger.info "Api response status_code => #{response_code}, headers => #{response_headers.inspect}, body => #{response_body.inspect}"
  end

  def response_success?
    response_success ? true : false
  end

  def service_unavailable_response?
    SERVICE_UNAVAILABLE_CODES.include?(response_code)
  end

  def send_request_with_logs
    log_response_with_time do
      begin
        send_channel_request
      rescue StandardError => e
        log_error(e)
        nil
      end
    end
  end

  # Needs to be defined in the child.
  # # This should be defined in the child class with their own choice http connection library
  # # This should return a response object
  # End
  def send_channel_request
    Rails.logger.info "#{klass_name} send_channel_request"
  end

  def klass_name
    self.class.name
  end

  def log_error(excpetion)
    log(OMNI_REQUEST_FAILED, log_info, excpetion, suppress_failure)
  end

  def log(type, error_info, exception = nil, silent = false)
    Rails.logger.error "TYPE=#{type}::INFO=#{error_info.inspect}"
    Rails.logger.error "EXP=#{exception.message}\n#{exception.backtrace[0..5].join("\n\t")}" if exception.present?
    raise_newrelic_error exception, error_info unless silent
  end

  def raise_newrelic_error(exception, error_info)
    NewRelic::Agent.notice_error(exception, custom_params: error_info)
  end

  def log_response_with_time
    response = nil
    time_taken = Benchmark.realtime { response = yield }
    Rails.logger.info "#OMNI API_CALL_INFO request_info=#{log_info.inspect}, response=#{response.presence.inspect}, response_time=#{time_taken.presence}"
    response
  rescue StandardError => e
    Rails.logger.info "Error while logging OMNI request/response exception=#{e.inspect}, backtrace=#{e.backtrace[0..5].join("\n\t")}}"
    nil
  end

  def filtered_params
    safe_send("#{action}_params")
  end

  def log_info
    {
      account_id: current_account.try(:id),
      user_id: current_user.try(:id),
      klass_name: klass_name,
      method: method,
      params: filtered_params
    }
  end

  private

    #     This is the base domain/url for which we want to create http connection.
    #     Suppose you want to hit ticket_field in freshdesk.
    #     domain = https://temp.freshdesk.com and full path is = https://temp.freshdesk.com/api/v2/ticket_fields
    #     so base_url can be -
    #       https://temp.freshdesk.com/  but then when you call get, post etc, then use the path "/api/v2/ticket_fields"
    #     But if you use base_url as -
    #       https://temp.freshdesk.com/api/v2 then path will be "ticket_fields"
    def base_url; end

    def http_connection
      Faraday::Connection.new(url: base_url)
    end

    def headers
      header = content_type
      header.merge!(client_id) if client_id.present? && client_id.is_a?(Hash)
      header.merge!(authorization_token) if authorization_token.present? && authorization_token.is_a?(Hash)
      header.merge!(custom_headers) if custom_headers.present? && custom_headers.is_a?(Hash)
      header
    end

    def content_type
      { 'Content-Type' => 'application/json' }
    end

  protected

    def current_account
      @current_account ||= Account.current
    end

    def current_user
      @current_user ||= current_account.all_users.where(id: performed_by_id).first
    end

    def unique_request_identifier
      Thread.current[:message_uuid].to_s
    end

    def common_identifier_params
      {
        identifiers: {
          bundle_id: current_account.omni_bundle_id.try(:to_s),
          request_id: unique_request_identifier,
          organisation_id: current_account.organisation_from_cache.try(:organisation_id).try(:to_s),
          account_id: current_account.id.to_s, # mandatory
          account_domain: current_account.full_domain,
          organisation_domain: current_account.organisation_from_cache.try(:domain),
          id: resource_id.to_s
        },
        actor: {
          freshid_user_id: current_user.try(:freshid_authorization).try(:uid).try(:to_s)
        }
      }
    end
end
