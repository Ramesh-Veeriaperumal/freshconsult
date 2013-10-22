class Support::SignupsController < SupportController
  
  before_filter { |c| c.requires_feature :signup_link } 
  before_filter :chk_for_logged_in_usr
  
  def chk_for_logged_in_usr
    if !preview? && logged_in?
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def new
    set_portal_page :user_signup
  end
  
  def create
    @user = current_account.users.new(params[:user])
    
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
      render :action => 'new'
    end
  end
end