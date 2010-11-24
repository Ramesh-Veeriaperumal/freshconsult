class UsersController < ApplicationController

  include ModelControllerMethods

  before_filter :check_user_limit, :only => :create
  #before_filter :require_no_user, :only => [:new, :create] #by Shan need to check later
  #before_filter :require_user, :only => [:show, :edit, :update]
  
  def create
    @user = current_account.users.new #by Shan need to check later
 
    if @user.signup!(params)
      #@user.deliver_activation_instructions! #Have moved it to signup! method in the model itself.
      flash[:notice] = "Your account has been created. Please check your e-mail for your account activation instructions!"
      redirect_to root_url
    else
      render :action => :new
    end
  end
  
  protected
  
    def scoper
      current_account.users
    end
    
    def authorized?
      (logged_in? && self.action_name == 'index') || admin?
    end
    
    def check_user_limit
      redirect_to new_user_url if current_account.reached_user_limit?
    end

end