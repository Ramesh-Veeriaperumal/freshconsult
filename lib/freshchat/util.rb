module Freshchat::Util
  include IntegrationProduct::Signup
  
  SYSTEM42_SERVICE = 'system42'.freeze
  def freshchat_signup
    response = HTTParty.post("#{Freshchat::Account::CONFIG[:signup][:host]}signup", body: freshchat_signup_body.to_json)
    Rails.logger.info "Response from freshchat_signup code - #{response.code} response - #{response}"
    if response.code == 201
      parsed_response = response.parsed_response
      save_freshchat_account(parsed_response['app_id'], parsed_response['widget_token'])
    end
    response
  end

  def sync_freshchat(app_id)
    query = { appAlias: app_id }
    response = HTTParty.put("#{Freshchat::Account::CONFIG[:signup][:host]}enable", query: query, body: { account: current_account.full_domain }.to_json, headers: sync_freshchat_headers(app_id))
    Rails.logger.info "Response from sync_freshchat #{response}"
    response
  end

  def enable_freshchat_feature
    if current_account.freshid_org_v2_enabled?
      freshchat_response = signup_via_aloha('freshchat')
      save_freshchat_v2_account(freshchat_response['product_signup_response']) if freshchat_response.code == 200
      freshchat_response
    end
    freshchat_response = signup_freshchat_account
    if freshchat_response.code == 200
      save_freshchat_account(freshchat_response['userInfoList'][0]['appId'], freshchat_response['userInfoList'][0]['webchatId']) if freshchat_response.try(:[], 'errorCode').blank?
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

  def freshchat_subscription_request(payload)
    options = {
      :headers => {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{sign_payload(payload)}",
        'x-fc-client-id' => 'OC_FD'
      },
      :body => payload.to_json
    }
    path = FreshchatSubscriptionConfig['subscription_host']
    Rails.logger.info "Freshchat Request Params :: #{URI.encode(path)} #{options.inspect}"
    request = HTTParty::Request.new(Net::HTTP::Post, URI.encode(path), options)
    freshchat_response = request.perform
    Rails.logger.info "Freshchat Response :: #{freshchat_response.body} #{freshchat_response.code} #{freshchat_response.message} #{freshchat_response.headers.inspect}"
    freshchat_response
  end

  private

    def save_freshchat_account(app_id, widget_token, portal_widget_enabled = false, enabled = true, domain = nil)
      current_account.create_freshchat_account(app_id: app_id, portal_widget_enabled: portal_widget_enabled, token: widget_token, enabled: enabled, domain: domain)
    end

    def save_freshchat_v2_account(response)
      freshchat_account = response['misc']['userInfoList'].select { |fc_acc| fc_acc['appIdReal'] == response['misc']['defaultApp'] }.first
      current_account.create_freshchat_account(app_id: freshchat_account['appId'], token: freshchat_account['webchatId'], domain: response['account']['domain'], portal_widget_enabled: true, enabled: true)
    end

    def freshchat_signup_body
      account_admin = current_account.roles.account_admin.first.users.first
      {
        emailId: account_admin.email,
        appName: current_account.domain,
        freshdeskIntegrationSettings: {
          account: current_account.full_domain,
        }
      }
    end

    def sync_freshchat_headers(app_id)
      jwt_token = sync_freshchat_jwt_token(app_id)
      {
        'X-FC-System42-Token' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    def sync_freshchat_jwt_token(app_id)
      JWT.encode sync_freshchat_payload(app_id), Freshchat::Account::CONFIG[:signup][:secret], 'HS256', { 'alg': 'HS256', 'typ': 'JWT' }
    end

    def sync_freshchat_payload(app_id)
      {}.tap do |claims|
        claims[:aud] = app_id.to_s
        claims[:exp] = Time.zone.now.to_i + 10.minutes
        claims[:iat] = Time.zone.now.to_i
        claims[:iss] = SYSTEM42_SERVICE
      end
    end

    def sign_payload(payload)
      JWT.encode(payload, FreshchatSubscriptionConfig['jwt_secret'], 'HS256', 'alg' => 'HS256', 'typ' => 'JWT')
    end
end
