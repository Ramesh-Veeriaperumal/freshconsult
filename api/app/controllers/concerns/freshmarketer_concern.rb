module FreshmarketerConcern
  extend ActiveSupport::Concern

  private

    def freshmarketer_client
      @freshmarketer_client ||= ::Freshmarketer::Client.new
    end

    def account_additional_settings
      @account_additional_settings ||= Account.current.account_additional_settings_from_cache
    end

    def client_error?
      freshmarketer_client.response_code != :ok
    end

    def render_client_error
      case freshmarketer_client.response_code
      when :duplicate_email_id
        render_request_error(:fm_duplicate_email, 409)
      when :invalid_credentials, :invalid_access_key, :invalid_scope, :scope_restricted
        render_request_error(:fm_invalid_token, 403)
      when :invalid_domain_name, :invalid_email_id, :invalid_account_id, :invalid_request, :invalid_user, :link_type_mismatch, :domain_email_mismatch
        render_request_error(:fm_invalid_request, 400)
      else
        render_base_error(:internal_error, 500)
      end
    end
end
