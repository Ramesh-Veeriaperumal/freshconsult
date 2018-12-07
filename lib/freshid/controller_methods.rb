module Freshid::ControllerMethods
  include Freshid::Authorization

  def self.included(base)
    base.send :helper_method, :freshid_enabled?
   end

  def authenticate_with_freshid
    session[:flash_message] = flash[:notice]
    session[:authorize] = true
    session[:freshid_auth_failure_return_to] = request.original_fullpath
    redirect_to_freshid_authorize and return
  end

  def redirect_to_agent_sso_freshid_authorize
    redirect_to_freshid_authorize(freshid_oauth_agent_authorize_callback_url, true)
  end

  def redirect_to_customer_sso_freshid_authorize
    redirect_to freshid_customer_authorize(freshid_oauth_customer_authorize_callback_url, freshid_logout_url, current_account.full_domain)
  end

  def redirect_to_freshid_authorize(callback_url=freshid_authorize_callback_url, sso=false)
    redirect_to freshid_authorize(callback_url, freshid_logout_url, current_account.full_domain, sso)
  end

  def redirect_to_freshid_login(options = {})
    redirect_to Freshid::Config.login_url(freshid_authorize_callback_url, freshid_logout_url, options)
  end

  def freshid_enabled_and_not_logged_in?
    !logged_in? && freshid_enabled? && !session.delete(:authorize) && !agent_oauth2_enabled?
  end

  def agent_oauth2_enabled_and_not_logged_in?
    !logged_in? && agent_oauth2_enabled?
  end

  def customer_oauth2_enabled_and_not_logged_in?
    !logged_in? && customer_oauth2_enabled?
  end

  def freshid_agent?(email, account = nil)
    account ||= current_account
    email.present? && freshid_enabled?(account) && account.all_technicians.find_by_email(email)
  end
  
  def freshid_enabled?(account = nil)
    account ||= current_account
    @freshid_enabled ||= account.freshid_enabled?
  end

  def agent_oauth2_enabled?
    current_account.oauth2_enabled? && current_account.freshid_enabled? && current_account.sso_enabled? && current_account.agent_oauth2_sso_enabled?
  end

  def customer_oauth2_enabled?
    current_account.oauth2_enabled? && current_account.freshid_enabled? && current_account.sso_enabled? && current_account.customer_oauth2_sso_enabled?
  end

end