module Freshcaller
  module Endpoints
    include Freshcaller::JwtAuthentication

    DELETE_INTEGRATION = '/integrations/freshdesk/delete'.freeze
    ENABLE_INTEGRATION = '/integrations/freshdesk/enable'.freeze
    DISABLE_INTEGRATION = '/integrations/freshdesk/disable'.freeze

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

    def protocol
      Rails.env.development? ? 'http://' : 'https://'
    end
  end
end
