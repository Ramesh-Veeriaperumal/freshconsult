class PasswordResetsController < SupportController
  
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :require_no_user
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  before_filter :set_native_mobile
 
  def new
    redirect_to support_login_path(:anchor => "forgot_password")
  end
  
  def create
    @user = current_account.user_emails.user_for_email(params[:email])
    if @user
      @user.deliver_password_reset_instructions! current_portal
	  message = t(:'flash.password_resets.email.success')
	    respond_to do |format|
          format.html {
          flash[:notice] = message
          redirect_to root_url
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
    if @user.save
      flash[:notice] = t(:'flash.password_resets.update.success')
      redirect_to root_url
    else
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      @user = current_account.users.find_using_perishable_token(params[:id],1.weeks)
      unless @user
        flash[:notice] = t(:'flash.password_resets.update.invalid_token')
        redirect_to root_url
      end
    end
end
