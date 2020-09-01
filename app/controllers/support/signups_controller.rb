class Support::SignupsController < SupportController

  include Support::SignupsHelper
  include Helpdesk::Permission::User
  
  before_filter { |c| c.requires_feature :signup_link }   
  before_filter :chk_signup_permission, :only => [:create]
  before_filter :chk_for_logged_in_usr 
  before_filter :initialize_user
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate_with_freshid, only: :new, if: :freshid_integration_enabled_and_not_logged_in?
  before_filter :set_validatable_custom_fields, :remove_noneditable_fields_in_params, :set_user_language,
                :set_required_fields, :remove_agent_params, :only => [:create]
  before_filter :set_i18n_locale
  
  def new
    respond_to do |format|
      format.html { set_portal_page :user_signup }
    end
  end
  
  def create
    if (current_account.bypass_signup_captcha_enabled? || verify_recaptcha(model: @user, message: t('captcha_verify_message'),
                        hostname: current_portal.method(:matches_host?))) && @user.signup!(params, current_portal)
      e_notification = current_account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
      if e_notification.requester_notification?
        flash[:notice] = t(:'activation_link', :email => @user.email)
      else
        flash[:notice] = t(:'activation_link_no_email')
      end
      redirect_to login_url
    else
      set_portal_page :user_signup
      render :action => :new
    end
  end

  private

    def remove_noneditable_fields_in_params # validation
      profile_field_names = current_account.contact_form.customer_signup_invisible_contact_fields.map(&:name)
      params[:user][:custom_field].except! *profile_field_names unless params[:user][:custom_field].nil?
      params[:user].except! *profile_field_names # except! pushed into Hash Class in will_paginate plugin
    end

    def remove_agent_params
      params[:user].except!(*agent_params)
    end

    def initialize_user
      # initializing & assigning in the same line causes errors (account_id is not assigned first)
      @user = current_account.users.new
    end

    def set_required_fields # validation
      required_signup_fields = customer_signup_fields.select{ |field| 
                    (field.field_type == :default_email) ? true : field.required_in_portal }
      @user.required_fields = { :fields => required_signup_fields, 
                                :error_label => :label_in_portal }
    end

    def set_user_language
      return unless current_account.features_included?(:multi_language)
      language = set_locale
      params[:user][:language] ||= (Languages::Constants::LANGUAGE_ALT_CODE[language] || language ||
        current_portal.language || current_account.language).to_s
    end

    def set_locale
      http_accept_language.compatible_language_from I18n.available_locales
    end

    def set_i18n_locale
      return if params[:url_locale].present?

      language = set_locale
      I18n.locale = language || current_portal.language
    end

    def set_validatable_custom_fields
      @user.validatable_custom_fields = { :fields => current_account.contact_form.custom_contact_fields, 
                                          :error_label => :label_in_portal }
    end

    def chk_for_logged_in_usr
      if !preview? && logged_in?
        redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
    end

    def chk_signup_permission
      redirect_on_signup_permission_fail(current_account, current_portal.id) unless has_signup_permission?(params[:user][:email], current_account)
    end

end
