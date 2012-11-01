# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  layout Proc.new { |controller| controller.request.headers['X-PJAX'] ? 'maincontent' : 'application' }
  
  before_filter :reset_current_account, :redirect_to_mobile_url
  before_filter :check_account_state, :except => [:show,:index]
  before_filter :set_default_locale
  before_filter :set_time_zone, :check_day_pass_usage 
  before_filter :set_locale

  rescue_from ActionController::RoutingError, :with => :render_404
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  
  include AuthenticationSystem
  #include SavageBeast::AuthenticationSystem
  include HelpdeskSystem
  
  include SslRequirement
  include SubscriptionSystem
  include Mobile::MobileHelperMethods
  
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
        return redirect_to(plan_subscription_url)
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
      TimeZone.set_time_zone
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

  def render_404
     NewRelic::Agent.notice_error(ActionController::RoutingError,{:uri => request.url,
                                                                  :referer => request.referer,
                                                                  :request_params => params})
    render :file => "#{Rails.root}/public/404.html", :status => :not_found
  end
  
  def record_not_found (exception)
    respond_to do |format|
      format.html do
        render :file => "#{Rails.root}/public/404.html", :status => :not_found
      end
      format.xml do 
        result = {:error=>exception.message}
        render :xml =>result.to_xml(:indent =>2,:root=> :errors),:status =>:not_found
      end
      format.json do 
        render :json => {:errors =>{:error =>exception.message}}.to_json,:status => :not_found
      end
    end
  end

  def handle_save_error (exception)
    respond_to do |format|
      format.xml do 
        result = {:error=>exception.message}
        result.to_xml(:indent =>2,:root=> :errors)
      end
      format.json do
       render :json => result.to_json
      end
    end
  end

  def handle_update_error (item)
    respond_to do | format|
      format.xml  { render :xml => item.errors.to_xml }
      format.json { render :json => {:errors=>{:error =>item.errors}}.to_json }
    end
  end

  protected
    def silence_logging
      @bak_log_level = logger.level 
      logger.level = Logger::ERROR
    end

    def revoke_logging
      logger.level = @bak_log_level 
    end
end

