# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  layout Proc.new { |controller| controller.request.headers['X-PJAX'] ? 'maincontent' : 'application' }

  include Api::ApplicationConcern
  around_filter :select_shard
  
  prepend_before_filter :determine_pod
  before_filter :unset_current_account, :unset_current_portal, :set_current_account
  before_filter :set_default_locale, :set_locale
  include SslRequirement
  include Authority::FreshdeskRails::ControllerHelpers
  before_filter :freshdesk_form_builder
  before_filter :remove_rails_2_flash_before
  before_filter :check_account_state, :except => [:show,:index]
  before_filter :set_time_zone, :check_day_pass_usage 
  before_filter :force_utf8_params
  before_filter :persist_user_agent
  before_filter :set_cache_buster
  before_filter :logging_details 
  before_filter :remove_pjax_param 

  after_filter :remove_rails_2_flash_after

  rescue_from ActionController::RoutingError, :with => :render_404
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from DomainNotReady, :with => :render_404

  
  include AuthenticationSystem
  include HelpdeskSystem  
  include ControllerLogger
  include SubscriptionSystem
  include Mobile::MobileHelperMethods
  
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'cf40acf193a63c36888fc1c1d4e94d32'
  skip_before_filter :verify_authenticity_token
  before_filter :verify_authenticity_token, :if => :api_request?
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  #
  

  def set_locale
    I18n.locale =  (current_user && current_user.language) ? current_user.language : (current_portal ? current_portal.language : I18n.default_locale) 
  end
 
  def activerecord_error_list(errors)
    error_list = '<ul class="error_list">'
    error_list << errors.collect do |e, m|
      "<li>#{e.to_s.humanize unless e.to_s == "base"} #{m}</li>"
    end.to_s << '</ul>'
    error_list.html_safe
  end
  
  def wrong_portal
    render :partial => "errors/error_page", :locals => 
      {
        :title => t(:'wrong_portal.title'),
        :description => t(:'wrong_portal.content_not_available')
      }
  end
  
  def set_default_locale
    I18n.locale = I18n.default_locale
  end

  def render_404
     # NewRelic::Agent.notice_error(ActionController::RoutingError,{:uri => request.url,
     #                                                              :referer => request.referer,
     #                                                              :request_params => params})
    render :file => "#{Rails.root}/public/404.html", :status => :not_found, :layout => false
  end
  
  def record_not_found(exception)
    Rails.logger.debug "Error  =>" + exception.message
    respond_to do |format|
      format.html {
        unless @current_account
          render("/errors/invalid_domain", :layout => false)
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
      format.widget do 
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
      format.widget { render :json => {:errors =>result}.to_json and return } 
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
    # Possible dead code
    def silence_logging
      @bak_log_level = logger.level 
      logger.level = Logger::ERROR
    end

    # Possible dead code
    def revoke_logging
      logger.level = @bak_log_level 
    end

    def remove_pjax_param
      params.delete('_pjax')
    end

  private
    def freshdesk_form_builder
      ActionView::Base.default_form_builder = FormBuilders::FreshdeskBuilder
    end

    #Clear rails 2 flash TO DO : Remove once migrated completely to rails 3
    def remove_rails_2_flash_before
      if self.flash and self.flash.class == ActionController::Flash::FlashHash
        self.flash.clear
      end
    end

    def remove_rails_2_flash_after
      if session[:flash] and session[:flash].class == ActionController::Flash::FlashHash
        session.delete(:flash)
      end
    end
    #End here
end

