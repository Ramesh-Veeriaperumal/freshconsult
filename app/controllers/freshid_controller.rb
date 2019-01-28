class FreshidController < ApplicationController
  include Freshid::CallbackMethods
  include ProfilesHelper

  FLASH_INVALID_USER    = 'activerecord.errors.messages.contact_admin'
  FLASH_USER_NOT_EXIST  = 'flash.general.access_denied'

  skip_before_filter :check_privilege, :verify_authenticity_token, :check_suspended_account, :check_account_state
  skip_before_filter :set_current_account, :redactor_form_builder, :set_time_zone, :check_day_pass_usage,
                     :set_locale, only: :event_callback

  def authorize_callback
    user = fetch_user_by_code(params[:code], freshid_authorize_callback_url, current_account)
    Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}"
    freshid_auth_failure_redirect_back and return if user.nil? && !authorize_via_freshworks_login_page?
    show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
    activate_user user
    create_user_session user
  end

  def agent_authorize_callback_helper(url)
    user = fetch_user_by_code(params[:code], url, current_account)
    Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}"
    show_login_error(user.nil?, !user.try(:valid_user?)) and return if user.nil? || !user.valid_user?
    activate_user user
    create_user_session(user)
  end

  def customer_authorize_callback_helper(url)
    freshid_user_data = fetch_freshid_end_user_by_code(params[:code], url, current_account)
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

  def oauth_agent_authorize_callback
    agent_authorize_callback_helper(freshid_oauth_agent_authorize_callback_url)
  end

  def oauth_customer_authorize_callback
    customer_authorize_callback_helper(freshid_oauth_customer_authorize_callback_url)
  end

  def saml_agent_authorize_callback
    agent_authorize_callback_helper(freshid_saml_agent_authorize_callback_url)
  end

  def saml_customer_authorize_callback
    customer_authorize_callback_helper(freshid_saml_customer_authorize_callback_url)
  end

  private

    def create_user_session(user)
      @user_session = current_account.user_sessions.new(user)
      @user_session.web_session = true
      if @user_session.save
        @current_user_session = @user_session
        @current_user = @user_session.record
        Rails.logger.info "FRESHID create_user_session :: a=#{current_account.try(:id)}, u=#{@current_user.try(:id)}"
        perform_after_login if @current_user.agent?
        redirect_back_or_default(default_return_url) if grant_day_pass
      else
        redirect_to login_url
      end
    end

    def show_login_error(user_not_present, invalid_user=false)
      error_message = (user_not_present ? FLASH_USER_NOT_EXIST : (invalid_user ? FLASH_INVALID_USER : nil))
      freshid_auth_failure_redirect_back(error_message, support_login_path) if error_message.present?
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

    def authorize_via_freshworks_login_page?
      !session[:authorize]
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
