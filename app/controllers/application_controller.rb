# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  layout Proc.new { |controller| controller.request.headers['X-PJAX'] ? 'maincontent' : 'application' }

  include Concerns::ApplicationConcern

  around_filter :select_shard
  
  prepend_before_filter :determine_pod
  around_filter :supress_logs, if: :can_supress_logs?

  before_filter :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :unset_thread_variables, :set_current_account, :reset_language
  before_filter :set_shard_for_payload
  before_filter :set_default_locale, :set_locale, :set_msg_id, :set_current_ip
  # before_filter :set_ui_preference
  include SslRequirement
  include Authority::FreshdeskRails::ControllerHelpers
  before_filter :freshdesk_form_builder
  before_filter :check_account_state, :except => [:show,:index]
  before_filter :set_time_zone, :check_day_pass_usage 
  before_filter :force_utf8_params
  before_filter :persist_user_agent
  before_filter :set_cache_buster
  #before_filter :logging_details 
  before_filter :remove_pjax_param
  before_filter :set_pjax_url
  after_filter :set_last_active_time, :reset_language
  after_filter :log_old_ui_path
  before_filter :check_session_timeout, if: :session_timeout_allowed?


  rescue_from ActionController::RoutingError, :with => :render_404
  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from ShardNotFound, :with => :record_not_found
  rescue_from DomainNotReady, :with => :render_domain_not_ready
  rescue_from AccountBlocked, :with => :render_account_blocked

  
  include AuthenticationSystem
  include HelpdeskSystem  
  #include ControllerLogger
  include SubscriptionSystem
  include Mobile::MobileHelperMethods
  include ActionView::Helpers::DateHelper
  include Freshid::ControllerMethods
  include AccountSetup
  
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'cf40acf193a63c36888fc1c1d4e94d32'
  skip_before_filter :verify_authenticity_token
  #before_filter :print_logs
  around_filter :log_csrf
  before_filter :verify_authenticity_token, :if => :web_request?
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  #

  # Will set the request url for pjax to change the state
  after_filter :remove_session_data

  OLD_UI_PATHS_TO_IGNORE = %w[/support /admin].freeze
  
  def set_pjax_url
    if is_ajax?
      response.headers['X-PJAX-URL'] = request.url
    end
  end

  def set_locale
    I18n.locale =  (current_user && current_user.language) ? current_user.language : (current_portal ? current_portal.language : I18n.default_locale) 
  end

  def set_current_ip
    Thread.current[:current_ip] = request.env['CLIENT_IP']
  rescue Exception => e
    Rails.logger.debug "Error getting currernt IP : #{e.message}"
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
            flash[:notice] = t('suspended_account_info')
            return redirect_to(subscription_url)
          else
            flash[:notice] = t('suspended_account_admin_info')
            redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
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
      set_account_meta_cookies
      log_session_details(:set_current_account) if Account.current.session_logs_enabled?
    rescue ActiveRecord::RecordNotFound
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      @destroy_session = true
      handle_unverified_request
    end    
  end

  def reset_language
    Language.reset_current
  end

  def show_password_expiry_warning
    if current_user and current_user.password_expiry and flash.blank? and web_request? and current_user.login_via_password?
      #get the remaining time for expiry in minutes
      time_to_expiry = (current_user.password_expiry - Time.now.utc).ceil
      flash[:notice] = t('flash.password_expiry', :time_in_words => time_ago_in_words((time_to_expiry).seconds.from_now)) if time_to_expiry < 60.minutes && time_to_expiry > 0
    end
  end
  
  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end

  def render_domain_not_ready
    render :file => "#{Rails.root}/public/DomainNotReady.html", :status => 403, :layout => false
  end
  
  def render_account_blocked
    render :file => "#{Rails.root}/public/AccountBlocked.html", :status => 403, :layout => false
  end

  def render_403
    render file: Rails.root.join('public/403.html').to_path, status: 403, layout: false
  end

  def render_404
     # NewRelic::Agent.notice_error(ActionController::RoutingError,{:uri => request.url,
     #                                                              :referer => request.referer,
     #                                                              :request_params => params})
    render :file => "#{Rails.root}/public/404.html", :status => :not_found, :layout => false
  end

  def render_500
    render :file => "#{Rails.root}/public/500.html", 
           :status => :internal_server_error, 
           :layout => false
  end

  def verify_format_and_tkt_id
    if request.format.nil?
      render_500
    elsif params[:id].to_i.zero?
      render_error
    end
  end

  def record_not_found(exception)
    Rails.logger.debug "Error  =>" + exception.message
    render_error
  end

  def render_error
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

  def check_anonymous_user
    access_denied unless logged_in?
  end

  def prevent_actions_for_sandbox
    if current_account.sandbox?
      respond_to do |format|
        restricted_error = { error: :forbidden }
        format.xml { render xml: restricted_error.to_xml }
        format.html { render_403 }
        format.any { render json: restricted_error }
      end
    end
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
      log_session_details(:handle_unverified_request) if Account.current.session_logs_enabled?
      Rails.logger.error "CSRF TOKEN NOT SET #{params.inspect}"
      if @destroy_session
        cookies.delete 'user_credentials'     
        current_user_session.destroy unless current_user_session.nil? 
        @current_user_session = @current_user = nil
      end
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

    def set_ui_preference
      @falcon_redirection_check = true
      cookies[:falcon_enabled] = true
      handle_falcon_redirection
    end

    def log_old_ui_path
      unless @falcon_redirection_check.present? || OLD_UI_PATHS_TO_IGNORE.any? { |path| request.path.include?(path) }
        FalconRedirection.log_referer(falcon_redirection_options)
      end
    rescue Exception => e
      Rails.logger.error "Exception while logging referer :: #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Exception while logging referer :: Accept Header #{request.headers['Accept']} ")
    end

    def falcon_redirection_options
      {
        request_referer: request.referer,
        not_html: !request.format.try(:html?),
        path_info: request.path_info,
        is_ajax: request.xhr?,
        env_path: env['PATH_INFO'],
        controller: self.class.name,
        action: request.params[:action],
        domain: request.domain
      }
    end

    def handle_falcon_redirection
      options = falcon_redirection_options
      result = FalconRedirection.falcon_redirect(options)
      redirect_to result[:path] if result[:redirect]
    end

    def is_ajax?
      request.xhr?
    end

    def set_last_active_time
      begin
        Sharding.run_on_master do
          current_user.agent.update_last_active if Account.current && current_user && current_user.agent? && !current_user.agent.nil?
        end
      rescue StandardError => e
        Rails.logger.error "Exception setting last activity :: #{e.message} :: #{Account.current.id if Account.current}"
      end
    end

    def request_host
      @request_host ||= request.host
    end

    def print_logs
      return unless Account.current && Account.current.launched?(:logout_logs)
      Rails.logger.error "Session CSRF key = #{session[:_csrf_token]}"
      Rails.logger.error "Request CSRF key = #{request.headers['X-CSRF-Token']}"
      Rails.logger.error "protocol = #{request.protocol}"
    end

    def non_covered_feature
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    end

    def non_covered_admin_feature
      redirect_to admin_home_index_path
    end

    def log_session_details(parent)
      Rails.logger.info "Session details logging :: #{parent} :: #{request.headers['X-CSRF-Token']} :: #{session.inspect}"
    end

    def log_csrf
      start_token = session[:_csrf_token] if session
      yield
      end_token = session[:_csrf_token] if session
      Rails.logger.info "CSRF observed :: changed :: true :: #{start_token} :: #{end_token}" if start_token != end_token
    end

    def remove_session_data
      session[:helpdesk_history] = nil if session && session[:helpdesk_history]
    end

    # namespaced controller name
    def nscname
      controller_path.tr('/', '_').singularize
    end

    def supress_logs(temporary_level = Logger::ERROR)
      if current_account.disable_supress_logs_enabled?
        yield
      else
        begin
          old_level = ActiveRecord::Base.logger.level
          ActiveRecord::Base.logger.level = temporary_level
          yield
        ensure
          ActiveRecord::Base.logger.level = old_level
        end
      end
    end

    # For handling json escape inside hash data
    def escape_html_entities_in_json(config_val = true)
      curr_value = ActiveSupport::JSON::Encoding.escape_html_entities_in_json
      ActiveSupport::JSON::Encoding.escape_html_entities_in_json = config_val
      yield
    ensure
      ActiveSupport::JSON::Encoding.escape_html_entities_in_json = curr_value
    end
end

