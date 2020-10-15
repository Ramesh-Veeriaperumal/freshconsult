# frozen_string_literal: true

class OmniChannelDashboard::Client
  include OmniChannelDashboard::Constants
  include Redis::OthersRedis
  include Redis::Keys::Others

  def initialize(endpoint, method, jwt_token, timeout = DEFAULT_TIMEOUT)
    @endpoint = endpoint
    @method = method
    @account = Account.current
    @jwt_token = jwt_token
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

  private

    def fetch_touchstone_response(payload_hash)
      url = @account.try(:full_domain) + @endpoint
      response = RestClient::Request.execute(
        method: @method,
        url: url,
        timeout: @timeout,
        payload: payload_hash,
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => @jwt_token.to_s
        }
      )
      response.code
    rescue StandardError => e
      Rails.logger.error "Failed to update touchstone for AccountId: #{@account.id} , Method: #{@method} URL: #{url} #{e.inspect}"
      403
    end
end
