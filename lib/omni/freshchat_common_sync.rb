# frozen_string_literal: true

class Omni::FreshchatCommonSync < Omni::ChannelSync
  include Freshchat::JwtAuthentication

  FEATURE_TOGGLE_PATH = 'v2/features'

  def send_channel_request
    super
    safe_send(method, safe_send("freshchat_#{resource_type}_#{action}_path"), update_params)
  end

  private

    def base_url
      Freshchat::Account::CONFIG[:apiHostUrl]
    end

    def update_params
      params
    end

    def freshchat_feature_toggle_update_path
      FEATURE_TOGGLE_PATH
    end

    def client_id
      { 'x-fc-client-id' => Freshchat::Account::CONFIG[:freshchatClient] }
    end

    def authorization_token
      { 'Authorization' => "Bearer #{freshchat_jwt_token}" }
    end
end
