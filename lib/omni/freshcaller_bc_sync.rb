class Omni::FreshcallerBcSync < Omni::ChannelSync
  include Freshcaller::Endpoints
  include Freshcaller::JwtAuthentication

  def send_channel_request
    super
    params.merge!(generate_request_id)
    freshcaller_request(safe_send("#{action}_params"), safe_send("#{action.to_s}_url"), method)
  end

  private

    def create_url
      freshcaller_create_bc
    end

    def get_url
      freshcaller_get_business_calendar(resource_id)
    end

    def delete_url
      get_url
    end

    def update_url
      freshcaller_update_business_calendar(resource_id)
    end

    def create_params
      params.merge(common_identifier_params)
    end

    def update_params
      params.merge(common_identifier_params)
    end

    def get_params
      params
    end

    def delete_params
      params
    end

    def generate_request_id
      {
        headers: {
          x_request_id: unique_request_identifier
        }
      }
    end

    def parse_response(raw_response)
      self.response_success = successful_sync? raw_response
      self.response_code = raw_response.code
      self.response_error_message = raw_response.message unless response_success
      self.response = raw_response.parsed_response # HTTPParty method
    end

    def successful_sync?(raw_response)
      SUCCESS_CODES.include?(raw_response.code)
    end
end
