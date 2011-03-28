# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  before_filter :set_time_zone
  
  before_filter :set_locale

  include AuthenticationSystem
  #include SavageBeast::AuthenticationSystem
  include HelpdeskSystem
  
  include SslRequirement
  include SubscriptionSystem
  
  include SentientController
  
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
#  helper_method :current_user_session, :current_user
#
#  private
#    def current_user_session
#      return @current_user_session if defined?(@current_user_session)
#      @current_user_session = UserSession.find
#    end
#
#    def current_user
#      return @current_user if defined?(@current_user)
#      @current_user = current_user_session && current_user_session.user
#    end
#
#    def require_user
#      unless current_user
#        store_location
#        flash[:notice] = "You must be logged in to access this page"
#        redirect_to new_user_session_url
#        return false
#      end
#    end
#
#    def require_no_user
#      if current_user
#        store_location
#        flash[:notice] = "You must be logged out to access this page"
#        redirect_to account_url
#        return false
#      end
#    end
#    
#    def store_location
#      session[:return_to] = request.request_uri
#    end
#    
#    def redirect_back_or_default(default)
#      redirect_to(session[:return_to] || default)
#      session[:return_to] = nil
#    end
def set_locale
  I18n.locale = request.compatible_language_from I18n.available_locales
end

  def set_time_zone
    #ActiveSupport::TimeZone.all
    begin
      current_account.make_current
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
  
end

