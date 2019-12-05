module Freshid::ControllerMethods
  include Freshid::Authorization

  def self.included(base)
    base.send :helper_method, :freshid_enabled?
    base.send :helper_method, :freshid_integration_enabled?
   end

  def authenticate_with_freshid
    session[:flash_message] = flash[:notice]
    session[:authorize] = true
    session[:freshid_auth_failure_return_to] = request.original_fullpath
    ( current_account.freshid_org_v2_enabled? ? redirect_to_freshid_v2_authorize : redirect_to_freshid_authorize ) and return
  end

  def redirect_to_agent_sso_freshid_authorize
    (freshid_org_v2_enabled? ? redirect_to_freshid_v2_authorize(true) : redirect_to_freshid_authorize(true)) and return
  end

  def redirect_to_customer_sso_freshid_authorize
    (freshid_org_v2_enabled? ? redirect_to_v2_customer_authorize : redirect_to_customer_authorize) and return
  end

  def redirect_to_freshid_authorize(sso = false)
    redirect_to freshid_authorize(freshid_authorize_callback_url, freshid_logout_url, current_account.full_domain, sso)
  end

  def redirect_to_freshid_v2_authorize(sso=false)
    redirect_to Freshid::V2::UrlGenerator.freshid_authorize(freshid_authorize_callback_url,
                  current_account.full_domain, sso)
  end

  def redirect_to_customer_authorize
    redirect_to customer_freshid_sso_enabled? ? freshid_customer_authorize(freshid_customer_authorize_callback_url, freshid_logout_url, current_account.full_domain) : support_login_path
  end

  def redirect_to_v2_customer_authorize
    redirect_to customer_freshid_sso_enabled? ? freshid_customer_authorize(freshid_customer_authorize_callback_url, freshid_logout_url, current_account.full_domain) : support_login_path
  end

  def redirect_to_freshid_login(options = {})
    redirect_to freshid_login_url(options)
  end

  def freshid_login_url(options = {})
    if freshid_enabled?
      Freshid::Config.login_url(freshid_authorize_callback_url, freshid_logout_url, options)
    elsif freshid_org_v2_enabled?
      Freshid::V2::UrlGenerator.login_url(freshid_authorize_callback_url, options)
    end
  end

  def freshid_v2_mobile_authorize_url(account)
    Freshid::V2::UrlGenerator.freshid_authorize(freshid_authorize_callback_url(host: account.full_domain, params: { mobile_login: true }), current_account.full_domain, false)
  end
  
  def freshid_integration_enabled_and_not_logged_in?
    !logged_in? && !session.delete(:authorize) && ((current_account.freshid_enabled? && !agent_freshid_sso_enabled?) || current_account.freshid_org_v2_enabled?)
  end

  def freshid_agent?(email, account = nil)
    account ||= current_account
    email.present? && freshid_integration_enabled?(account) && account.all_technicians.find_by_email(email)
  end
  
  def freshid_enabled?(account = nil)
    account ||= current_account
    @freshid_enabled ||= account.freshid_enabled?
  end
  
  def freshid_integration_enabled?(account = current_account)
    @freshid_integration_enabled ||= account.freshid_integration_enabled?
  end

  def freshid_org_v2_enabled?(account = current_account)
    @freshid_org_v2_enabled ||= account.freshid_org_v2_enabled?
  end

  def freshid_profile_url
    profile_url = ""
    if freshid_org_v2_enabled?
      org_domain = current_account.organisation_domain
  		profile_url = Freshid::V2::UrlGenerator.profile_url(Freshid::V2::UrlGenerator.login_url(freshid_authorize_callback_url))
    else
      profile_url = Freshid::Config.profile_url(Freshid::Config.login_url(freshid_authorize_callback_url, freshid_logout_url))
    end
    profile_url
  end

  def agent_oauth2_enabled?
    current_account.agent_oauth2_sso_enabled? && current_account.freshid_enabled?
  end

  def customer_oauth2_enabled?
    current_account.customer_oauth2_sso_enabled? && current_account.freshid_integration_enabled?
  end

  def agent_freshid_saml_enabled?
    current_account.agent_freshid_saml_sso_enabled? && current_account.freshid_enabled?
  end

  def customer_freshid_saml_enabled?
    current_account.customer_freshid_saml_sso_enabled? && current_account.freshid_integration_enabled?
  end

  def agent_freshid_sso_enabled?
    agent_oauth2_enabled? || agent_freshid_saml_enabled?
  end

  def customer_freshid_sso_enabled?
    customer_oauth2_enabled? || customer_freshid_saml_enabled?
  end

end
