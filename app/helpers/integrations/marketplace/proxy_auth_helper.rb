module Integrations::Marketplace::ProxyAuthHelper
  include GoogleProxySignupHelper

  def sso_redirect(proxy_auth_user)
    reset_user_session
    if proxy_auth_user.privilege?(:manage_account)
      google_sso(proxy_auth_user) if @app_name == "google"
    else
      flash.now[:notice] = t(:'flash.general.insufficient_privilege.admin')
      render "google_signup/signup_google_error"
    end
  end

  private

    def reset_user_session
      @check_session.destroy if @check_session.present?
    end

end