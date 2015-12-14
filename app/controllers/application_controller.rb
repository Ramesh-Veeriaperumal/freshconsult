# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  layout Proc.new { |controller| controller.request.headers['X-PJAX'] ? 'maincontent' : 'application' }

  include Concerns::ApplicationConcern
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
  after_filter :set_last_active_time

  after_filter :remove_rails_2_flash_after

  rescue_from ActionController::RoutingError, :with => :render_404
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from DomainNotReady, :with => :render_404

  
  include AuthenticationSystem
  include HelpdeskSystem  
  include ControllerLogger
  include SubscriptionSystem
  include Mobile::MobileHelperMethods
  include ActionView::Helpers::DateHelper

  
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'cf40acf193a63c36888fc1c1d4e94d32'
  skip_before_filter :verify_authenticity_token
  before_filter :verify_authenticity_token, :if => :web_request?
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  #

  def set_locale
    I18n.locale =  (current_user && current_user.language) ? current_user.language : (current_portal ? current_portal.language : I18n.default_locale) 
  end
 
  def check_account_state
    unless current_account.active? 
      respond_to do |format|
        account_suspended_hash = {:account_suspended => true}

        format.xml { render :xml => account_suspended_hash.to_xml }
        format.json { render :json => account_suspended_hash.to_json }
        format.nmobile { render :json => account_suspended_hash.to_json }
        format.js { render :json => account_suspended_hash.to_json }
        format.widget { render :json => account_suspended_hash.to_json }
        format.html { 
          if privilege?(:manage_account)
            flash[:notice] = t('suspended_plan_info')
            return redirect_to(subscription_url)
          else
            flash[:notice] = t('suspended_plan_admin_info', :email => current_account.admin_email) 
            redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) 
          end
        }
      end
    end
  end
  
  def set_time_zone
    TimeZone.set_time_zone
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
  
  # Check set_current_account method in api_applciation_controller if this method is modified.
  def set_current_account
    begin
      current_account.make_current
      User.current = current_user
    rescue ActiveRecord::RecordNotFound
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      handle_unverified_request
    end    
  end

  def show_password_expiry_warning
    if current_user and current_user.password_expiry and flash.blank? and web_request? and current_user.login_via_password?
      #get the remaining time for expiry in minutes
      time_to_expiry = (current_user.password_expiry - Time.now.utc).ceil
      flash[:notice] = t('flash.password_expiry', :time_in_words => time_ago_in_words((time_to_expiry).seconds.from_now)) if time_to_expiry < 60.minutes && time_to_expiry > 0
    end
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
      format.nmobile do 
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

    def handle_unverified_request
      super
      Rails.logger.error "CSRF TOKEN NOT SET #{params.inspect}"
      cookies.delete 'user_credentials'     
      current_user_session.destroy unless current_user_session.nil? 
      @current_user_session = @current_user = nil
      portal_redirect_url = root_url
      if params[:portal_type] == "facebook"
        portal_redirect_url = portal_redirect_url + "support/home"
      else
        portal_redirect_url = portal_redirect_url + "support/login"
      end
      respond_to do |format|
        format.html  {
          redirect_to portal_redirect_url
        }
        format.nmobile{
          render :json => {:logout => 'success'}.to_json
        }
        format.json{
          render :json => {:logout => 'success'}
        }
        format.widget{
          render :json => {:logout => 'success'}
        }
      end
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

    def web_request?
      request.cookies["_helpkit_session"]
    end

    def set_last_active_time
      current_user.agent.update_last_active if current_user && current_user.agent? && !current_user.agent.nil?
    end
end

