# frozen_string_literal: true

class Omni::FreshcallerCommonSync < Omni::ChannelSync
  include Freshcaller::JwtAuthentication
  include Freshcaller::Endpoints

  FEATURE_TOGGLE_PATH = '/features'

  def send_channel_request
    super
    safe_send(method, safe_send("freshcaller_#{resource_type}_#{action}_path"), update_params)
  end

  private

    def freshcaller_feature_toggle_update_path
      FEATURE_TOGGLE_PATH
    end

    def update_params
      params
    end

    def custom_headers
      { 'Accept' => 'application/json' }
    end

    def authorization_token
      { 'Authorization' => "Freshdesk token=#{sign_payload}" }
    end

    alias base_url freshcaller_url
end
