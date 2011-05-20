class UsersController < ApplicationController 
  
  
  include ModelControllerMethods #Need to remove this, all we need is only show.. by Shan. to do must!

  before_filter :set_selected_tab
  skip_before_filter :load_object , :only => [ :show, :edit]
  
  ##redirect to contacts
  def index
    redirect_to contacts_url
  end
    
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
    logger.debug "in users controller :: show show"
    user_role = current_account.all_users.find(params[:id]).user_role    
    if User::USER_ROLES_KEYS_BY_TOKEN[:customer].eql?(user_role)      
      redirect_to :controller =>'contacts' ,:action => 'show', :id => params[:id]    
    else    
      agent_id = current_account.all_agents.find_by_user_id(params[:id]).id
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

    def set_selected_tab
      @selected_tab = 'Customers'
    end
  
end