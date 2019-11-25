module FreshcallerConcern
  extend ActiveSupport::Concern

  OK = 200

  ERROR_MAPPING = {
    '404' => [:fc_invalid_domain_name, 400],
    '403' => [:fc_access_denied, 403],
    '422' => [:fc_unprocessable_entity, 400],
    'password_incorrect' => [:fc_password_incorrect, 400],
    'access_restricted' => [:fc_access_restricted, 403]
  }.freeze

  private

    def client_error?
      freshcaller_response.code != OK || freshcaller_response['error'].present?
    end

    def linked?
      freshcaller_response['freshcaller_account_id'].present?
    end

    def render_client_error
      error_code = freshcaller_response.code != OK ? freshcaller_response.code.to_s : freshcaller_response['error_code']
      if ERROR_MAPPING.key?(error_code)
        render_request_error(*ERROR_MAPPING[error_code])
      else
        render_request_error(freshcaller_response.message, freshcaller_response.code)
      end
    end
end
