# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  
  before_filter :reset_current_account
  before_filter :check_account_state, :except => [:show,:index]
  before_filter :set_default_locale
  before_filter :set_time_zone, :check_day_pass_usage 
  before_filter :set_locale
  
  include AuthenticationSystem
  #include SavageBeast::AuthenticationSystem
  include HelpdeskSystem
  
  include SslRequirement
  include SubscriptionSystem
  
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'cf40acf193a63c36888fc1c1d4e94d32'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  #
  
  # Scrub sensitive parameters from your log
  filter_parameter_logging :password, :password_confirmation

  def set_locale
    I18n.locale =  (current_user && current_user.language) ? current_user.language : (current_portal ? current_portal.language : I18n.default_locale) 
  end
 
  def check_account_state
    if !current_account.active? 
      if permission?(:manage_account)
        flash[:notice] = t('suspended_plan_info')
        return redirect_to(plan_account_url)
      else
        flash[:notice] = t('suspended_plan_admin_info',:email => current_account.account_admin.email) 
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
     end
  end
  
  def set_time_zone
    begin
      current_account.make_current
      User.current = current_user
      Time.zone = current_user ? current_user.time_zone : (current_account ? current_account.time_zone : Time.zone)
    rescue ActiveRecord::RecordNotFound
    end
  end
  
  def activerecord_error_list(errors)
    error_list = '<ul class="error_list">'
    error_list << errors.collect do |e, m|
      "<li>#{e.humanize unless e == "base"} #{m}</li>"
    end.to_s << '</ul>'
    error_list
  end
  
  def wrong_portal
    render("/errors/wrong_portal")
  end
  
  def set_default_locale
    I18n.locale = I18n.default_locale
  end
  
  def reset_current_account
    Thread.current[:account] = nil
  end
  
end

