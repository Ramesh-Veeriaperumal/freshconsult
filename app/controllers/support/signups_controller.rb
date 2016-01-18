class Support::SignupsController < SupportController

  include Support::SignupsHelper
  
  before_filter { |c| c.requires_feature :signup_link } 
  before_filter :chk_for_logged_in_usr
  before_filter :initialize_user
  skip_before_filter :verify_authenticity_token
  before_filter :set_validatable_custom_fields, :remove_noneditable_fields_in_params, :set_language,
                :set_required_fields, :only => [:create]
  
  def new
    respond_to do |format|
      format.html { set_portal_page :user_signup }
    end
  end
  
  def create
    if verify_recaptcha(:model => @user, :message => t("captcha_verify_message")) && @user.signup!(params, current_portal)
      e_notification = current_account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
      if e_notification.requester_notification?
        flash[:notice] = t(:'activation_link', :email => params[:user][:email])
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

    def set_language
      params[:user][:language] ||= ( http_accept_language.compatible_language_from I18n.available_locales || 
        current_portal.language || current_account.language
      ).to_s
    end

    def set_validatable_custom_fields
      @user.validatable_custom_fields = { :fields => current_account.contact_form.custom_contact_fields, 
                                          :error_label => :label_in_portal }
    end

    def chk_for_logged_in_usr
      if !preview? && logged_in?
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
    end
end