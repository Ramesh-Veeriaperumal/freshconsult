class ActivationsController < ApplicationController
  #before_filter :require_no_user, :only => [:new, :create] #Guess we don't really need this - Shan
  
  def send_invite
    puts "Send Activation"
    flash[:notice] = "Activation email has been sent to the User!"
    redirect_to(:back)
  end
  
  def new
    @user = current_account.users.find_using_perishable_token(params[:activation_code], 1.weeks) 
    if @user.nil?
      flash[:notice] = "Your activation code has been expired !"
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
