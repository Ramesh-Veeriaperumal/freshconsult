# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  layout Proc.new { |controller| controller.request.headers['X-PJAX'] ? 'maincontent' : 'application' }

  around_filter :select_shard
  
  before_filter :unset_current_account, :set_current_account
  include Authority::Rails::ControllerHelpers
  before_filter :freshdesk_form_builder
  before_filter :check_account_state, :except => [:show,:index]
  before_filter :set_default_locale
  before_filter :set_time_zone, :check_day_pass_usage 
  before_filter :set_locale, :force_utf8_params
  before_filter :persist_user_agent
  before_filter :set_cache_buster
  before_filter :logging_details 

  rescue_from ActionController::RoutingError, :with => :render_404
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from DomainNotReady, :with => :render_404

  
  include AuthenticationSystem
  include HelpdeskSystem  
  include ControllerLogger
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
    unless current_account.active? 
      if privilege?(:manage_account)
        flash[:notice] = t('suspended_plan_info')
        return redirect_to(subscription_url)
      else
        flash[:notice] = t('suspended_plan_admin_info', :email => current_account.admin_email) 
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
     end
  end
  
  def set_time_zone
    TimeZone.set_time_zone
  end
  
  def activerecord_error_list(errors)
    error_list = '<ul class="error_list">'
    error_list << errors.collect do |e, m|
      "<li>#{e.humanize unless e == "base"} #{m}</li>"
    end.to_s << '</ul>'
    error_list.html_safe
  end
  
  def wrong_portal
    render("/errors/wrong_portal")
  end
  
  def set_default_locale
    I18n.locale = I18n.default_locale
  end
  
  def unset_current_account
    Thread.current[:account] = nil
  end
  
  def set_current_account
    begin
      current_account.make_current
      User.current = current_user
    rescue ActiveRecord::RecordNotFound
    end    
  end

  def render_404
     # NewRelic::Agent.notice_error(ActionController::RoutingError,{:uri => request.url,
     #                                                              :referer => request.referer,
     #                                                              :request_params => params})
    render :file => "#{Rails.root}/public/404.html", :status => :not_found
  end
  
  def record_not_found (exception)
    Rails.logger.debug "Error  =>" + exception.message
    respond_to do |format|
      format.html {
        unless @current_account
          render("/errors/invalid_domain")
        else
          render_404
        end
      }
      format.xml do 
        result = {:error=>"Record Not Found"}
        render :xml =>result.to_xml(:indent =>2,:root=> :errors),:status =>:not_found
      end
      format.json do 
        render :json => {:errors =>{:error =>"Record Not Found"}}.to_json,:status => :not_found
      end
    end
  end
 
 
  def handle_error (error)
    Rails.logger.debug "API::Error  =>" + error.message
    result = {:error => error.message}
    respond_to do | format|
      format.xml  { render :xml => result.to_xml(:indent =>2,:root=>:errors)  and return }
      format.json { render :json => {:errors =>result}.to_json and return } 
    end
  end
 

  def select_shard(&block)
    Sharding.select_shard_of(request.host) do 
        yield 
    end
  end

  def persist_user_agent
    Thread.current[:http_user_agent] = request.env['HTTP_USER_AGENT']
  end

  def set_cache_buster
      response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end

  protected
    def silence_logging
      @bak_log_level = logger.level 
      logger.level = Logger::ERROR
    end

    def revoke_logging
      logger.level = @bak_log_level 
    end

  private
    def freshdesk_form_builder
      ActionView::Base.default_form_builder = FormBuilders::FreshdeskBuilder
    end

    # See http://stackoverflow.com/questions/8268778/rails-2-3-9-encoding-of-query-parameters
    # See https://rails.lighthouseapp.com/projects/8994/tickets/4807
    # See http://jasoncodes.com/posts/ruby19-rails2-encodings (thanks for the following code, Jason!)
    def force_utf8_params
      traverse = lambda do |object, block|
        if object.kind_of?(Hash)
          object.each_value { |o| traverse.call(o, block) }
        elsif object.kind_of?(Array)
          object.each { |o| traverse.call(o, block) }
        else
          block.call(object)
        end
        object
      end
      force_encoding = lambda do |o|
        RubyBridge.force_utf8_encoding(o)
      end
      traverse.call(params, force_encoding)
    end

    def handle_unverified_request
      super
      cookies.delete 'user_credentials'
      @current_user_session = @current_user = nil
    end
end

