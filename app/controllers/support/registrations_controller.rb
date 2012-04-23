class Support::RegistrationsController < Support::SupportController
  
  before_filter { |c| c.requires_feature :signup_link }
  before_filter :chk_for_logged_in_usr
  
  def chk_for_logged_in_usr
    if logged_in?
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end
  
  def create
    @user = current_account.users.new
    return render :action => 'new' if  !verify_recaptcha(:model => @user,:message => "Captcha verification failed, try again!")
    if @user.signup!(params , current_portal)
      flash[:notice] = "successfully registered activation link has been sent to #{params[:user][:email]}"
      redirect_to login_url
    else
      render :action => 'new'
    end
  end
end