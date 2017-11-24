class Support::LoginController < SupportController

  include Redis::RedisKeys
  include Redis::TicketsRedis
  include SsoUtil
  include Helpdesk::Permission::User
  
  MAX_ATTEMPT = 3
  SUB_DOMAIN = "freshdesk.com"

  skip_before_filter :check_suspended_account
  before_filter :set_no_ssl_msg, :only => :new
  skip_before_filter :check_account_state
  after_filter :set_domain_cookie, :only => :create
  skip_after_filter :set_last_active_time
  before_filter :set_custom_flash_message
  before_filter :only => :create do |c|
    redirect_to_freshid_login if params[:user_session].try(:[], :email) && freshid_agent?(params[:user_session][:email])
  end
  before_filter :authenticate_with_freshid, only: :new, if: :freshid_enabled_and_not_logged_in?

  def new
    if current_account.sso_enabled? and check_request_referrer 
      sso_login_page_redirect #TODO : change this to allow different sign on for customer and agent
    else
      @user_session = current_account.user_sessions.new
      respond_to do |format|
        format.html { set_portal_page :user_login }
      end
    end
  end

  def create
    @user_session = current_account.user_sessions.new(params[:user_session])
    @user_session.web_session = true
    @verify_captcha = (params['g-recaptcha-response'.to_sym] ? verify_recaptcha : true )
    if @verify_captcha && @user_session.save
      @current_user_session = current_account.user_sessions.find
      @current_user = @current_user_session.record
      if @current_user_session && !@current_user && @current_user_session.stale_record && @current_user_session.stale_record.password_expired 
        stale_user = @current_user_session.stale_record
        stale_user.reset_perishable_token!

        redirect_to(edit_password_reset_path(stale_user.perishable_token))
      else
        remove_old_filters if @current_user.agent?
        redirect_back_or_default('/') if grant_day_pass 
        #Unable to put 'grant_day_pass' in after_filter due to double render
      end
    else
      note_failed_login
          show_recaptcha?
      handle_deleted_user_login
      set_portal_page :user_login
      render :action => :new
    end
  end

  private

    def set_no_ssl_msg
      if session[:return_to].present? and show_ssl_msg?(session[:return_to])
        flash[:error] = t('no_ssl_redirection')
      end
    end

    def show_ssl_msg?(return_url)
      return_url.include?(billing_subscription_path) and current_portal.portal_url.present? and 
        request.referrer.include?(current_portal.portal_url) and !current_portal.ssl_enabled?
    end

    def note_failed_login
      user_info = params[:user_session][:email] if params[:user_session]
      logger.warn "Failed login for '#{user_info.to_s}' from #{request.remote_ip} at #{Time.now.utc}"
    end

    def show_recaptcha?
      unless @verify_captcha
        @user_session.errors.add(:base, t("captcha_verify_message"))
        @show_recaptcha = true
        return
      end
      if params['g-recaptcha-response'.to_sym] || has_reached_max_attempt?
        @show_recaptcha = true
      end
    end

    def has_reached_max_attempt?
      @user_session.attempted_record && @user_session.attempted_record.failed_login_count >= MAX_ATTEMPT
    end

    def handle_deleted_user_login
      if params[:user_session] && !(params[:user_session][:email].blank? || params[:user_session][:password].blank?)
        login_user = current_account.all_users.find_by_email(params[:user_session][:email])
        if !login_user.nil? && login_user.deleted?
          @user_session.errors.clear
        @user_session.errors.add(:base,I18n.t("activerecord.errors.messages.contact_admin"))
      end
      end
    end

    def remove_old_filters
      remove_tickets_redis_key(HELPDESK_TICKET_FILTERS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]})
      remove_tickets_redis_key(EXPORT_TICKET_FIELDS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]})
    end

    def check_request_referrer
      request.referrer ? (URI(request.referrer).path != "/login/normal") : true
    end

    def set_domain_cookie
      if @current_user and @current_user.helpdesk_agent? and current_portal
        cookies[:helpdesk_url] = { :value => current_portal.host, :domain => SUB_DOMAIN }
      end
    end      

    def decide_smart_sso_login_page # Possible dead code
      # If the user logged as an agent then assume redirection to SSO  - TODO use a cookie may
      # if customer portal has any other login option enabled then customer need to be able to login
      # If not redirect customer to SSO portal .
      allow_non_saml_cust_login = ( current_account.features?(:google_signin) or current_account.features?(:facebook_signin) or
                                    current_account.features?(:twitter_signin) or current_account.features?(:signup_link) );
      if allow_non_saml_cust_login
        # show login page
        set_portal_page :user_login
      else
        #redirect to SSO login page
        sso_login_page_redirect
      end
    end

    def set_custom_flash_message      
      flash[:notice] = login_access_denied_message if params[:restricted_helpdesk_login_fail]
      flash[:notice] = session.delete(:flash_message) if session[:flash_message]
    end
		
		def default_return_url
			@default_return_url ||= begin
				from_cookie = cookies[:return_to] # The :return_url cookie will be used by Ember App
				cookies.delete(:return_url) if from_cookie.present?
				# TODO-EMBERAPI: Cookie deletion does not seem reflect properly on the client
				from_cookie || '/'
			end
		end

end

