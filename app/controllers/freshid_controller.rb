class FreshidController < ApplicationController
  include Freshid::CallbackMethods
  include Freshid::ControllerMethods
  include ProfilesHelper

  FLASH_INVALID_USER    = 'activerecord.errors.messages.contact_admin'
  FLASH_USER_NOT_EXIST  = 'flash.general.access_denied'

  ONBOARDING_ROUTE = '/a/getstarted'.freeze

  MOBILE_PKCE_AUTH_KEYS = %w[access_token expires_in id].freeze

  skip_before_filter :check_privilege, :verify_authenticity_token, :check_suspended_account, :check_account_state
  skip_before_filter :set_current_account, :redactor_form_builder, :set_time_zone, :check_day_pass_usage,
                     :set_locale, :check_session_timeout, only: :event_callback

  def authorize_callback
    current_account.freshid_org_v2_enabled? ? authorize_callback_v2_helper :
      authorize_callback_helper
  end

  def customer_authorize_callback
    if current_account.freshid_org_v2_enabled? &&
        current_account.freshid_sso_sync_enabled? &&
        current_account.contact_custom_sso_enabled?
      customer_authorize_callback_v2_entrypoint_helper
    elsif current_account.freshid_org_v2_enabled?
      customer_authorize_callback_v2_helper
    else
      customer_authorize_callback_helper
    end
  end

  def mobile_auth_token
    if MOBILE_PKCE_AUTH_KEYS.all? { |s| params.key? s }
      user = current_account.all_technicians.find_by_freshid_uuid(params[:id])
      org_domain = current_account.organisation_domain
      access_token = params[:access_token]
      refresh_token = params[:refresh_token]
      expires_in = params[:expires_in]
      Rails.logger.info "Mobile PKCE login user auth token :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}, organisation domain:#{org_domain}"
      mobile_auth_failure('User not found') && return if user.nil?
      activate_user user
      create_user_session_for_mobile_pkce_login(user, access_token, refresh_token, expires_in)
    else
      mobile_auth_failure('Invalid parameters')
    end
  end

  private

    def create_user_session(user, access_token = nil, refresh_token = nil, access_token_expires_in = nil)
      @user_session = current_account.user_sessions.new(user)
      @user_session.web_session = true
      mobile_login = params[:mobile_login] || false
      mobile_scheme = params[:scheme]
      if @user_session.save
        @current_user_session = @user_session
        @current_user = @user_session.record
        store_freshid_tokens(access_token, refresh_token, access_token_expires_in) if (access_token.present? && refresh_token.present?)
        Rails.logger.info "FRESHID create_user_session :: a=#{current_account.try(:id)}, u=#{@current_user.try(:id)}"
        perform_after_login if @current_user.agent?
        set_freshid_session_info_in_cookie if current_account.freshid_org_v2_enabled?
        return unless grant_day_pass
        set_cookies_for_mobile if is_native_mobile?
        mobile_and_freshid_v2?(mobile_login) ? redirect_to_mobile_freshid_login(@current_user, mobile_scheme) : redirect_back_or_default(default_return_url)
      else
        cookies['mobile_access_token'] = { :value => 'failed', :http_only => true } if is_native_mobile?
        redirect_to login_url && return unless mobile_and_freshid_v2?(mobile_login)
        Rails.logger.error "FRESHID MOBILE LOGIN :: Failed :: a=#{current_account.try(:id)}"
        redirect_to Freshid::V2::UrlGenerator.mobile_login_url(current_account.full_domain, login: 'failed', scheme: mobile_scheme)
      end
    end

    def create_user_session_for_mobile_pkce_login(user, access_token = nil, refresh_token = nil, access_token_expires_in = nil)
      @user_session = current_account.user_sessions.new(user)
      @user_session.web_session = true
      if @user_session.save
        @current_user_session = @user_session
        @current_user = @user_session.record
        store_freshid_tokens(access_token, refresh_token, access_token_expires_in) if access_token.present? && refresh_token.present?
        Rails.logger.info "FRESHID create_user_session (PKCE) :: a=#{current_account.try(:id)}, u=#{@current_user.try(:id)}"
        perform_after_login if @current_user.agent?
        set_freshid_session_info_in_cookie if current_account.freshid_org_v2_enabled?
        mobile_auth_failure('Session creation failed') && return unless grant_day_pass(true)
        set_cookies_for_mobile if is_native_mobile?
        mobile_auth_success(@current_user)
      else
        cookies['mobile_access_token'] = { value: 'failed', http_only: true } if is_native_mobile?
        Rails.logger.error "FRESHID MOBILE LOGIN (PKCE) :: Failed :: a=#{current_account.try(:id)}"
        mobile_auth_failure('Session creation failed')
      end
    end

    def mobile_and_freshid_v2?(mobile_login = false)
      current_account.freshid_org_v2_enabled? && mobile_login
    end

    def mobile_auth_success(user)
      render json: { login_status: 'success', token: user.mobile_auth_token, email: user.email }, status: 200
    end

    def mobile_auth_failure(message)
      render json: { login_status: 'failed', message: message }, status: 400
    end

    def set_cookies_for_mobile
      cookies['mobile_access_token'] = { :value => @current_user.mobile_auth_token, :http_only => true }
      cookies['fd_mobile_email'] = { :value => @current_user.email, :http_only => true }
    end

    def redirect_to_mobile_freshid_login(user, scheme)
      query_params = { login: 'success', token: user.mobile_auth_token, email: user.email, scheme: scheme }
      redirect_to Freshid::V2::UrlGenerator.mobile_login_url(current_account.full_domain, query_params)
    end

    def show_login_error(user_not_present, invalid_user=false)
      if params[:mobile_login]
        redirect_to freshid_login_url(mobile_login: true, scheme: params[:scheme])
      else
        error_message = (user_not_present ? FLASH_USER_NOT_EXIST : (invalid_user ? FLASH_INVALID_USER : nil))
        freshid_auth_failure_redirect_back(error_message, support_login_path) if error_message.present?
      end
    end

    def perform_after_login
      remove_old_filters
      set_domain_cookie
    end

    def remove_old_filters
      remove_tickets_redis_key(HELPDESK_TICKET_FILTERS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]})
      remove_tickets_redis_key(EXPORT_TICKET_FIELDS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => request.session_options[:id]})
    end

    def set_domain_cookie
      cookies[:helpdesk_url] = { :value => current_portal.host, :domain => AppConfig['base_domain'][Rails.env] } if current_portal
    end

    def authorize_via_freshdesk_login?
      session[:authorize]
    end  

    def default_return_url
      is_trial = current_account.subscription.trial?

      @default_return_url ||= begin
        from_cookie = cookies[:return_to] # The :return_url cookie will be used by Ember App
        cookies.delete(:return_url) if from_cookie.present?
        # TODO-EMBERAPI: Cookie deletion does not seem reflect properly on the client
        is_trial && @current_user.privilege?(:admin_tasks) ? from_cookie || ONBOARDING_ROUTE : from_cookie || '/'
      end
    end

    def set_freshid_session_info_in_cookie
      cookies[:session_state] = params[:session_state]
      cookies[:session_token] = params[:session_token] if params[:session_token].present?
    end

    def authorize_callback_helper 
      user = fetch_user_by_code(params[:code], freshid_authorize_callback_url, current_account)
      Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}"
      freshid_auth_failure_redirect_back and return if user.nil? && authorize_via_freshdesk_login?
      show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
      activate_user user
      create_user_session(user)
    end
    
    def authorize_callback_v2_helper
      org_domain = current_account.organisation_domain
      freshid_authorize_url = params[:mobile_login] ? freshid_authorize_callback_url(mobile_login: params[:mobile_login], scheme: params[:scheme]) : freshid_authorize_callback_url
      response = Freshid::V2::LoginUtil.fetch_user_by_code(org_domain, params[:code], freshid_authorize_url, current_account)
      user = response.present? ? response[:user] : nil
      Rails.logger.info "FRESHID V2 authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}, organisation domain:#{org_domain}"
      freshid_auth_failure_redirect_back and return if user.nil? && authorize_via_freshdesk_login?
      show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
      activate_user user
      create_user_session(user, response[:access_token], response[:refresh_token], response[:access_token_expires_in])
    end

    def freshid_v2_redirect_url
      params[:mobile_login] ? freshid_authorize_callback_url(mobile_login: true, scheme: params[:scheme]) : freshid_authorize_callback_url
    end
    
    def customer_authorize_callback_helper
      freshid_user_data = fetch_freshid_end_user_by_code(params[:code], freshid_customer_authorize_callback_url, current_account)
      email = freshid_user_data.try(:[], :email)
      user = nil
      if email.present?
        user = current_account.user_emails.user_for_email(email) || current_account.users.new(email: email)
        Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}"
        user.assign_freshid_attributes_to_contact(freshid_user_data)
        user.save if user.changed?
      end
      show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
      create_user_session(user)
    end
    
    def customer_authorize_callback_v2_helper
      freshid_user_data = fetch_freshid_end_user_by_code(params[:code], freshid_customer_authorize_callback_url, current_account)
      email = freshid_user_data.try(:[], :email)
      user = nil
      if email.present?
        user = current_account.user_emails.user_for_email(email) || current_account.users.new(email: email)
        Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}"
        user.assign_freshid_attributes_to_contact(freshid_user_data)
        user.save if user.changed?
      end
      show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
      create_user_session(user)
    end

    def customer_authorize_callback_v2_entrypoint_helper
      org_domain = current_account.organisation_domain
      freshid_user_data_token = Freshid::V2::LoginUtil.fetch_contact_token_by_code(org_domain, params[:code], freshid_customer_authorize_callback_url)
      decoded_token_hash = JWT.decode(freshid_user_data_token, nil, false)
      freshid_user_data = nil
      email = nil
      if decoded_token_hash.present?
        freshid_user_data_collection = decoded_token_hash.select { |user_data| user_data.key?('email') }
        freshid_user_data = freshid_user_data_collection.first.presence
        email = freshid_user_data.try(:[], 'email')
      else
        Rails.logger.info "Not able to decode the user token - #{freshid_user_data_token}"
      end
      user = nil
      if email.present?
        user = current_account.user_emails.user_for_email(email) || current_account.users.new(email: email)
        Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}, email=#{email}"
        user.assign_freshid_attributes_to_contact(freshid_user_data)
        user.save if user.changed?
      end
      show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
      create_user_session(user)
    end

    def store_freshid_tokens(access_token, refresh_token, access_token_expires_in)
      @current_user.store_user_access_token(access_token, access_token_expires_in)
      @current_user.store_user_refresh_token(refresh_token)
    end
end
