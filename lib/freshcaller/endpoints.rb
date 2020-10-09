module Freshcaller
  module Endpoints
    include Freshcaller::JwtAuthentication

    DELETE_INTEGRATION = '/integrations/freshdesk/delete'.freeze
    ENABLE_INTEGRATION = '/integrations/freshdesk/enable'.freeze
    DISABLE_INTEGRATION = '/integrations/freshdesk/disable'.freeze
    UPDATE_INTEGRATION = '/integrations/freshdesk/update'.freeze
    OMNI_INTEGRATION = '/integrations/support360/update'.freeze

    OMNI_BC_PATH = '/ufx/v1/business_hours'.freeze

    def freshcaller_base_sso_url
      "#{protocol}#{current_account.freshcaller_account.domain}/sso/freshdesk/#{sign_payload(email: current_user.email)}"
    end

    def freshcaller_custom_redirect_url(redirect_path)
      "#{freshcaller_base_sso_url}?redirect_path=#{redirect_path}"
    end

    def freshcaller_admin_rules_url
      freshcaller_custom_redirect_url('/admin/rules')
    end

    def freshcaller_widget_url
      return "#{protocol}localhost:4201/widget/" if Rails.env.development?
      "#{protocol}#{::Account.current.freshcaller_account.domain}/widget/"
    end

    def freshcaller_link_url
      "#{protocol}#{params[:url]}#{FreshcallerConfig['domain_suffix']}/link_account"
    end

    def freshcaller_url
      "#{protocol}#{::Account.current.freshcaller_account.domain}"
    end

    def freshcaller_disconnect_url
      "#{freshcaller_url}#{DELETE_INTEGRATION}"
    end

    def freshcaller_enable_url
      "#{freshcaller_url}#{ENABLE_INTEGRATION}"
    end

    def freshcaller_disable_url
      "#{freshcaller_url}#{DISABLE_INTEGRATION}"
    end

    def freshcaller_add_agent_url
      "#{freshcaller_url}/users"
    end

    def freshcaller_integration_update_url
      "#{freshcaller_url}#{UPDATE_INTEGRATION}"
    end

    def freshcaller_omni_integration_update_url
      "#{freshcaller_url}#{OMNI_INTEGRATION}"
    end

    def freshcaller_update_agent_url(user_id)
      "#{freshcaller_url}/users/#{user_id}"
    end

    def freshcaller_create_bc
      format('%{url}%{path}', url: freshcaller_url, path: OMNI_BC_PATH)
    end

    def freshcaller_get_business_calendar(calendar_id)
      format('%{base_url}/%{id}', base_url: freshcaller_create_bc, id: calendar_id)
    end

    def freshcaller_update_business_calendar(calendar_id)
      format('%{business_calendar_base_url}/%{id}', business_calendar_base_url: freshcaller_base_business_calendar_url, id: calendar_id)
    end

    def freshcaller_base_business_calendar_url
      format('%{url}%{path}', url: freshcaller_url, path: OMNI_BC_PATH)
    end

    def protocol
      Rails.env.development? ? 'http://' : 'https://'
    end
  end
end
