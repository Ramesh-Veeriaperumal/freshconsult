module Freshid::ControllerMethods
  include Freshid::Authorization

  def self.included(base)
    base.send :helper_method, :freshid_enabled?
   end

  def authenticate_with_freshid
    session[:flash_message] = flash[:notice]
    session[:authorize] = true
    session[:freshid_auth_failure_return_to] = request.original_fullpath
    redirect_to freshid_authorize(freshid_authorize_callback_url, freshid_logout_url) and return
  end

  def redirect_to_freshid_login
    redirect_to Freshid::Config.login_url(freshid_authorize_callback_url, freshid_logout_url)
  end
  
  def freshid_enabled_and_not_logged_in?
    !logged_in? && freshid_enabled? && !session.delete(:authorize)
  end
  
  def freshid_agent?(email, account = nil)
    account ||= current_account
    email.present? && freshid_enabled?(account) && account.all_technicians.find_by_email(email)
  end
  
  def freshid_enabled?(account = nil)
    account ||= current_account
    @freshid_enabled ||= account.freshid_enabled?
  end
end