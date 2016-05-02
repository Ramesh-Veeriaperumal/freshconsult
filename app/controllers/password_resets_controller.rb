class PasswordResetsController < SupportController
  
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :require_no_user
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  before_filter :load_password_policy, :only => :edit
  before_filter :set_native_mobile
 
  def new
    redirect_to support_login_path(:anchor => "forgot_password")
  end
  
  def create
    @user = current_account.user_emails.user_for_email(params[:email])
    if @user
      if (@user.active? || @user.agent? || user_activation_enabled) && @user.allow_password_reset?
        @user.deliver_password_reset_instructions! current_portal 
        message      = t(:'flash.password_resets.email.success')
        redirect_url = root_url
      else
        message      = t(:'flash.password_resets.email.not_allowed')
        redirect_url = login_path
      end
	    respond_to do |format|
          format.html {
          flash[:notice] = message
          redirect_to redirect_url
        }
        format.nmobile {
          render :json => {:server_response => message, :reset_password => 'success'}
        }
      end	    
    else
	  message = t(:'flash.password_resets.email.user_not_found')
      respond_to do |format|
        format.html {
          flash[:notice] = message	  
	      if mobile?
    	    redirect_to root_url
      	  else
        	# render :action => :new
	        redirect_to support_login_path(:anchor => "forgot_password")
		  end
		}
        format.nmobile {
          render :json => {:server_response => message, :reset_password => 'failure'}
        }
      end
    end
  end
  
  def edit
    set_portal_page :password_reset
  end

  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    @user.active = true #by Shan need to revisit..
    if @user.password.present? && (@user.password == @user.password_confirmation) && @user.save
      @user.reset_perishable_token!
      flash[:notice] = t(:'flash.password_resets.update.success')
      redirect_to root_url
    else
      load_password_policy
      set_portal_page :password_reset
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      @user = current_account.users.find_using_perishable_token(params[:id],1.weeks)
      if @user
        unless @user.allow_password_reset?
          flash[:notice] = t(:'flash.password_resets.email.not_allowed')
          redirect_to login_path
        end
      else
        flash[:notice] = t(:'flash.password_resets.update.invalid_token')
        redirect_to root_url
      end
    end

    def load_password_policy
      @password_policy = @user.agent? ? current_account.agent_password_policy : current_account.contact_password_policy
    end
    
    def user_activation_enabled
      current_account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION).requester_notification?
    end
end
