class FreshidController < ApplicationController
  include Freshid::CallbackMethods

  FLASH_INVALID_USER    = 'activerecord.errors.messages.contact_admin'
  FLASH_USER_NOT_EXIST  = 'flash.general.access_denied'

  skip_before_filter :check_privilege, :verify_authenticity_token, :check_suspended_account, :check_account_state
  skip_before_filter :set_current_account, :redactor_form_builder, :set_time_zone, :check_day_pass_usage,
                     :set_locale, only: :event_callback

  def authorize_callback
   authorize_and_create_session
  end

  def oauth_agent_authorize_callback
    authorize_and_create_session(freshid_oauth_agent_authorize_callback_url)
  end

  private

    def create_user_session(user)
      @user_session = current_account.user_sessions.new(user)
      @user_session.web_session = true
      if @user_session.save
        @current_user_session = @user_session
        @current_user = @user_session.record
        Rails.logger.info "FRESHID create_user_session :: a=#{current_account.try(:id)}, u=#{@current_user.try(:id)}"
        perform_after_login
        redirect_back_or_default('/') if grant_day_pass
      else
        redirect_to login_url
      end
    end

    def authorize_and_create_session(callback_url=freshid_authorize_callback_url)
      user = fetch_user_by_code(params[:code], callback_url, current_account)
      Rails.logger.info "FRESHID authorize_callback :: user_present=#{user.present?} , user=#{user.try(:id)}, valid_user=#{user.try(:valid_user?)}"
      freshid_auth_failure_redirect_back and return if user.nil? && session[:authorize]
      freshid_auth_failure_redirect_back(FLASH_USER_NOT_EXIST, support_login_path) and return if user.nil? && authorize_via_freshworks_login_page?
      freshid_auth_failure_redirect_back(FLASH_INVALID_USER) and return if !user.valid_user?
      activate_user user
      create_user_session user
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

end
