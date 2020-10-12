# Abstract class
class Omni::BusinessCalendarSync
  OMNI_REQUEST_FAILED = 'OMNI_REQUEST_FAILED'.freeze
  attr_accessor :resource_id, :action, :channel, :method, :params, :performed_by_id, :response, :response_success, :response_code,
                :response_error_message, :suppress_failure

  ACTION_MAPPING = {
    create: :post,
    update: :put,
    delete: :delete,
    get: :get
  }.freeze

  SUCCESS_CODES = (200..204).freeze
  SERVICE_UNAVAILABLE_CODES = (500..504).to_a.freeze

  def initialize(args)
    %i[action channel resource_id params performed_by_id].each { |name| self.safe_send("#{name}=", args[name.to_sym]) }
    self.method = ACTION_MAPPING[action.to_sym]
    self.params = args[:params] || {}
  end

  def sync_channel
    raw_response = send_request_with_logs
    parse_response(raw_response)
  end

  # Needs to be defined in the child
  # # The child class should define this to parse the response object
  # # Attributes response_success, response_code, response_error_message, response should be set in this method
  # End
  def parse_response(raw_response); end

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
  def send_channel_request; end

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
                 freshid_user_id: current_user.freshid_authorization.uid.try(:to_s)
        }
      }
    end
end
