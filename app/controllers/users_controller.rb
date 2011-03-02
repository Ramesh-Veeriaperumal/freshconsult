class UsersController < ApplicationController 
  
  include ModelControllerMethods

  before_filter :check_user_limit, :only => :create
  #before_filter :require_no_user, :only => [:new, :create] #by Shan need to check later
  #before_filter :require_user, :only => [:show, :edit, :update]
  before_filter :set_selected_tab
    
  def new
    redirect_to new_contact_url
  end
  
  def edit
    redirect_to edit_contact_url
  end
  
  def create
    
    @user = current_account.users.new #by Shan need to check later       
    if @user.signup!(params)
      #@user.deliver_activation_instructions! #Have moved it to signup! method in the model itself.
      flash[:notice] = "The user has been created and activation instructions sent to #{@user.email}!"
      redirect_to users_url
    else
      render :action => :new
    end
  end
  
   
  def show
    
    user_role = User.find(params[:id]).user_role    
    if User::USER_ROLES_KEYS_BY_TOKEN[:customer].eql?(user_role)      
      redirect_to :controller =>'contacts' ,:action => 'show', :id => params[:id]    
    else    
      agent_id = Agent.find_by_user_id(params[:id]).id
      redirect_to :controller =>'agents' ,:action => 'show', :id => agent_id    
    end
    
  end
  
  def delete_avatar
    load_object
    @user.avatar.destroy
    render :text => "success"
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

    def set_selected_tab
      @selected_tab = 'Customers'
    end
  
end