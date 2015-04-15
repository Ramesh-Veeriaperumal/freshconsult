class ActivationsController < SupportController
  #before_filter :require_no_user, :only => [:new, :create] #Guess we don't really need this - Shan

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:new, :create]
  
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

  def new_email
    @email = current_account.user_emails.find_email_using_perishable_token(params[:activation_code],
                 1.weeks)
    if @email.nil?
      flash[:notice] = t('users.activations.code_expired')
    else
      if !@email.user.active? or @email.user.crypted_password.blank?
        @user = @email.user
        set_portal_page :activation_form 
        return
      else
        if @email.verified?
          flash[:notice] = t('merge_contacts.email_activated')
        else
          @email.mark_as_verified
          flash[:notice] = t('merge_contacts.new_email_activation')
        end
      end
    end
    redirect_to home_index_path
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
      set_portal_page :activation_form
      render :action => :new
    end
  end

  protected

    def cname
      "users" #possible dead code
    end

    def scoper
      current_account.users #possible dead code
    end
end
