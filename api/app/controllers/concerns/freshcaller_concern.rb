module FreshcallerConcern
  extend ActiveSupport::Concern

  RETRY_LIMIT = 3

  OK = 200

  ERROR_MAPPING = {
    '404' => [:fc_invalid_domain_name, 400],
    '403' => [:fc_access_denied, 403],
    '422' => [:fc_unprocessable_entity, 400],
    'password_incorrect' => [:fc_password_incorrect, 400],
    'access_restricted' => [:fc_access_restricted, 403],
    'spam_email' => [:fc_spam_email, 403],
    'domain_taken' => [:fc_domain_taken, 400]
  }.freeze

  private

    def signup_account
      @freshcaller_response = enable_freshcaller_feature
      @retry = 1
      while domain_taken_error? && @retry < RETRY_LIMIT
        @freshcaller_response = enable_freshcaller_feature
        @retry += 1
      end
      freshcaller_response
    end

    def client_error?
      freshcaller_response && (freshcaller_response.code != OK || freshcaller_response['error_code'].present?)
    end

    def domain_taken_error?
      client_error? && freshcaller_response['error_code'] && freshcaller_response['error_code'] == 'domain_taken'
    end

    def linked?
      freshcaller_response && freshcaller_response['freshcaller_account_id'].present?
    end

    def render_client_error
      error_code = freshcaller_response['error_code'] ? freshcaller_response['error_code'] : freshcaller_response.code.to_s
      if ERROR_MAPPING.key?(error_code)
        render_request_error(*ERROR_MAPPING[error_code])
      else
        render_request_error(freshcaller_response['error_code'], freshcaller_response.code)
      end
    end
end
