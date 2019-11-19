module FreshcallerConcern
  extend ActiveSupport::Concern

  private

    def client_error?(freshcaller_response)
      freshcaller_response.code != 200
    end

    def render_client_error(freshcaller_response)
      case freshcaller_response.code
      when :invalid_credentials, :invalid_access_key, :invalid_scope, :scope_restricted
        render_request_error(:fc_invalid_token, 403)
      when :unprocessable_entity
        render_request_error('Unprocessable Entity', 422)
      when :invalid_domain_name
        render_request_error(:fc_invalid_request, 400)
      else
        render_request_error(freshcaller_response.message, freshcaller_response.code)
      end
    end
end
