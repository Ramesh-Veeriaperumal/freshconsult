module Freshchat::Util
  SERVICE = 'system42'.freeze
  def signup
    response = HTTParty.post("#{Freshchat::Account::CONFIG[:signup][:host]}signup", body: body.to_json)
    Rails.logger.info "Response from signup freshchat #{response}"
    parsed_response = response.parsed_response
    save_freshchat_account(parsed_response['app_id'], parsed_response['widget_token'])
  end

  def sync_freshchat(app_id)
    query = { appAlias: app_id }
    response = HTTParty.put("#{Freshchat::Account::CONFIG[:signup][:host]}enable", query: query, body: sync_freshchat_body.to_json, headers: headers(app_id))
    Rails.logger.info "Response from sync_freshchat #{response}"
  end

  def enable_freshchat_feature
    freshchat_response = signup_freshchat_account
    if freshchat_response.code == 200
      save_freshchat_account(freshchat_response['userInfoList'][0]['appId'], freshchat_response['userInfoList'][0]['appKey']) if freshchat_response.try(:[], 'errorCode').blank?
    end
    freshchat_response
  end

  def signup_freshchat_account
    plan_enum = Subscription::FRESHCHAT_PLAN_MAPPING[current_account.plan_name]
    path = "#{Freshchat::Account::CONFIG[:agentWidgetHostUrl]}/app/v1/signup/unity_signup?email=#{CGI.escape(current_user.email)}"
    path << "&plan=#{plan_enum}" if plan_enum.present?
    path << '&first_referrer=Freshdesk omnichannel'
    request = HTTParty::Request.new(Net::HTTP::Post, URI.encode_www_form(path))
    freshchat_response = request.perform
    freshchat_response
  end

  private

    def save_freshchat_account(app_id, widget_token, portal_widget_enabled = false, enabled = true)
      Freshchat::Account.create(app_id: app_id, portal_widget_enabled: portal_widget_enabled, token: widget_token, enabled: enabled)
    end

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
