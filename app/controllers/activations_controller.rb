class ActivationsController < SupportController
  #before_filter :require_no_user, :only => [:new, :create] #Guess we don't really need this - Shan

  skip_before_filter :check_privilege, :only => [:new, :create]
  
  def send_invite
    user = current_account.all_users.find params[:id]
    user.deliver_activation_instructions!(current_portal, true) if user and user.has_email?
    respond_to do |format|
      format.html { 
        flash[:notice] = t('users.activations.send_invite_success') 
        redirect_to(:back)
      }
      format.js { 
        render :json => { :activation_sent => true }
      }
    end
  end

  def new
    @user = current_account.users.find_using_perishable_token(params[:activation_code], 1.weeks) 
    if @user.nil?
      flash[:notice] = t('users.activations.code_expired')
      return redirect_to new_password_reset_path
    end
    set_portal_page :activation_form
  end

  def create
    unless params[:perishable_token].blank? 
      @user = current_account.users.find_by_perishable_token(params[:perishable_token]) 
    end
    if @user && @user.activate!(params)
      flash[:notice] = t('users.activations.success')
      @current_user = @user
      redirect_to(root_url) if grant_day_pass
    else
      render :action => :new
    end
  end

  protected

    def cname
      "users"
    end

    def scoper
      current_account.users
    end
end
