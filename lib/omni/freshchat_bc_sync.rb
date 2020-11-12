# frozen_string_literal: true

class Omni::FreshchatBcSync < Omni::ChannelSync
  include Freshchat::JwtAuthentication
  BC_PATH = 'v2/business_hours'

  def send_channel_request
    super
    create_connection.safe_send(method) do |request|
      request.body = safe_send("#{action.to_s}_params")
      Rails.logger.info "#{klass_name} Request:: #{request.inspect} for Account #{current_account.id}"
    end
  end

  private

    def create_url
      business_calendar_host_url
    end

    def get_url
      format('%{url}/%{id}', url: business_calendar_host_url, id: resource_id)
    end

    def delete_url
      get_url
    end

    def update_url
      format('%{url}/%{id}', url: business_calendar_host_url, id: resource_id)
    end

    def create_params
      params.merge(common_identifier_params)
    end
    
    def get_params
      params
    end

    def update_params
      params.merge(common_identifier_params)
    end

    def delete_params
      params
    end

    def parse_response(raw_response)
      self.response_success = successful_sync?(raw_response) # raw_response is Faraday::Response object
      self.response_code = raw_response.status
      self.response_error_message = raw_response.body['message'].presence || raw_response.body['errorMessage'] unless response_success
      self.response = raw_response.body
    end

    def successful_sync?(raw_response)
      SUCCESS_CODES.include?(raw_response.status)
    end

    def freshchat_domain
      current_account.freshchat_account.api_domain
    end

    def business_calendar_host_url
      "https://#{freshchat_domain}/#{BC_PATH}"
    end

    def create_connection
      connection = Faraday.new(url: safe_send("#{action}_url")) do |conn|
        conn.request :json
        conn.adapter Faraday.default_adapter
        conn.response :json
      end
      connection.headers = {
                             'x-fc-client-id' => Freshchat::Account::CONFIG[:freshchatClient],
                             'Content-Type' => 'application/json',
                             'Authorization' => "Bearer #{freshchat_jwt_token}"
      }
      connection
    end
end
