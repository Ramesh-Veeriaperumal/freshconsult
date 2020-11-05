# frozen_string_literal: true

class OmniChannelDashboard::Client
  include OmniChannelDashboard::Constants
  include Iam::AuthToken
  include Redis::OthersRedis
  include Redis::Keys::Others

  def initialize(endpoint, method, jwt_token = '', timeout = DEFAULT_TIMEOUT)
    @endpoint = endpoint
    @method = method
    @account = Account.current
    @jwt_token = jwt_token.presence || construct_jwt_with_bearer(User.current)
    @timeout = timeout
  end

  def account_create_or_update(payload_hash)
    response = fetch_touchstone_response(payload_hash)
    if SUCCESS.include?(response) && !@account.omni_channel_dashboard_enabled?
      @account.launch(:omni_channel_dashboard)
      @account.launch(:omni_channel_team_dashboard) if redis_key_exists?(OMNI_TEAM_DASHBOARD_ENABLED_ON_SIGNUP)
      Rails.logger.info("Omni Channel Dashboard feature is enabled for A - #{@account.id}.")
    end
  end

  def widget_data_request
    response = HTTParty.get(@endpoint, headers: generate_headers.merge(widget_data_headers), timeout: @timeout)
    Rails.logger.info "touchstone X-Request-ID - #{response.headers['x-touchstone-request-id']}"
    [JSON.parse(response.body), response.code]
  rescue StandardError => e
    Rails.logger.error "Failed to update touchstone for AccountId: #{@account.id} , Method: #{@method} URL: #{@endpoint} #{e.inspect}"
    [ERROR_RESPONSE, 502]
  end

  private

    def fetch_touchstone_response(payload_hash)
      url = @account.try(:full_domain) + @endpoint
      response = RestClient::Request.execute(
        method: @method,
        url: url,
        timeout: @timeout,
        payload: payload_hash,
        headers: generate_headers
      )
      Rails.logger.info "touchstone X-Request-ID - #{response.headers[:x_touchstone_request_id]}"
      response.code
    rescue StandardError => e
      Rails.logger.error "Failed to update touchstone for AccountId: #{@account.id} , Method: #{@method} URL: #{url} #{e.inspect}"
      403
    end

    def generate_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => @jwt_token.to_s
      }
    end

    def widget_data_headers
      {
        'x-timezone' => GMT_OFFSET + ActiveSupport::TimeZone.new(Account.current.time_zone).formatted_offset,
        'accept-language' => User.current.language.to_s,
        'X-Client-ID' => Thread.current[:message_uuid].last.to_s
      }
    end
end
