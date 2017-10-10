module Freshcaller
  module Endpoints
    include Freshcaller::JwtAuthentication

    def freshcaller_base_sso_url
      "https://#{current_account.freshcaller_account.domain}/sso/freshdesk/#{sign_payload(email: current_user.email)}"
    end

    def freshcaller_custom_redirect_url(redirect_path)
      "#{freshcaller_base_sso_url}?redirect_path=#{redirect_path}"
    end

    def freshcaller_admin_rules_url
      freshcaller_custom_redirect_url('/admin/rules')
    end
  end
end
