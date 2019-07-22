module Freshchat::Util
  SERVICE = 'system42'.freeze
  def signup
    response = HTTParty.post("#{Freshchat::Account::CONFIG[:signup][:host]}signup", body: body.to_json)
    Rails.logger.info "Response from signup freshchat #{response}"
    parsed_response = response.parsed_response
    Freshchat::Account.create(app_id: parsed_response['app_id'], portal_widget_enabled: false, token: parsed_response['widget_token'], enabled: true)
  end

  def sync_freshchat(app_id)
    query = { appAlias: app_id }
    response = HTTParty.put("#{Freshchat::Account::CONFIG[:signup][:host]}enable", query: query, body: sync_freshchat_body.to_json, headers: headers(app_id))
    Rails.logger.info "Response from sync_freshchat #{response}"
  end

  private

    def body
      current_user = current_account.roles.account_admin.first.users.first
      {
        emailId: current_user.email,
        appName: current_account.domain,
        freshdeskIntegrationSettings: {
          account: current_account.full_domain,
          token: current_user.single_access_token
        }
      }
    end

    def sync_freshchat_body
      current_user = current_account.roles.account_admin.first.users.first
      {
        account: current_account.full_domain,
        token: current_user.single_access_token
      }
    end

    def headers(app_id)
      jwt_token = construct_jwt_token(app_id)
      {
        'X-FC-System42-Token' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    def construct_jwt_token(app_id)
      JWT.encode payload(app_id), Freshchat::Account::CONFIG[:signup][:secret], 'HS256', { 'alg': 'HS256', 'typ': 'JWT' }
    end

    def payload(app_id)
      {}.tap do |claims|
        claims[:aud] = app_id.to_s
        claims[:exp] = Time.now.to_i + 10.minutes
        claims[:iat] = Time.now.to_i
        claims[:iss] = SERVICE
      end
    end
end
