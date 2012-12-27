class Support::SignupsController < SupportController
  
  before_filter { |c| c.requires_feature :signup_link }
  
  before_filter :chk_for_logged_in_usr
  
  def chk_for_logged_in_usr
    if logged_in?
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

  def new
    set_portal_page :user_signup
  end
  
  def create
    @user = current_account.users.new
    
    if verify_recaptcha(:model => @user, :message => t("captcha_verify_message")) && @user.signup!(params, current_portal)
      flash[:notice] = t("signup_complete_activate_info")
      redirect_to login_url
    else
      set_portal_page :user_signup
      render :action => 'new'
    end
  end
end