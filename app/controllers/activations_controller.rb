class ActivationsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create] #Guess we don't really need this - Shan
  before_filter :only => :send_invite do |c| 
    c.requires_permission :manage_users
  end
  
  def send_invite
    user = current_account.all_users.find params[:id]
    user.deliver_contact_activation if user
    
    flash[:notice] = "Activation email has been sent!"
    redirect_to(:back)
  end
  
  def new
    @user = current_account.users.find_using_perishable_token(params[:activation_code], 1.weeks) 
    if @user.nil?
      flash[:notice] = "Your activation code has been expired!"
      return redirect_to new_password_reset_path
    end
    raise Exception if @user.active?
  end

  def create
    @user = current_account.users.find(params[:id])
 
    raise Exception if @user.active?
 
    if @user.activate!(params)
      flash[:notice] = "Your account has been activated."
      redirect_to root_url
    else
      render :action => :new
    end
  end

end
