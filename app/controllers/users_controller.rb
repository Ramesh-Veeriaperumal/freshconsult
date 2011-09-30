class UsersController < ApplicationController 
  
  
  include ModelControllerMethods #Need to remove this, all we need is only show.. by Shan. to do must!
  include HelpdeskControllerMethods

  before_filter :set_selected_tab
  skip_before_filter :load_object , :only => [ :show, :edit]
  
  before_filter :only => :change_account_admin do |c| 
    c.requires_permission :manage_account
  end
  
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_multiple_items, :only => :block
  
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
  
  def block
    @items.each do |item|
      item.deleted = true 
      item.save if item.customer?
    end
    flash[:notice] = "Following contacts #{ @items.map {|u| u.name}.join(', ') } has been blocked "
  end
  
   
  def show
    logger.debug "in users controller :: show show"
    user = current_account.all_users.find(params[:id])        
    if(user.customer? )
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
  
  def change_account_admin 
    pre_owner_saved, new_owner_saved = false, false    
    User.transaction do
      if current_account.account_admin.id != params[:account_admin].to_i
        @pre_owner = current_account.account_admin
        @pre_owner.user_role =  User::USER_ROLES_KEYS_BY_TOKEN[:admin]
        @new_owner = current_account.admins.find(params[:account_admin])
        @new_owner.user_role =  User::USER_ROLES_KEYS_BY_TOKEN[:account_admin]
        pre_owner_saved = @pre_owner.save 
        new_owner_saved = @new_owner.save 
      end
    end
    if pre_owner_saved and new_owner_saved
      flash[:notice] = t('account_admin_updated')
      redirect_to admin_home_index_url
    else
      redirect_to account_url
    end
  end

 
  protected
  
    def scoper
      current_account.all_users
    end
    
    def authorized?
      (logged_in? && self.action_name == 'index') || admin?
    end

    def set_selected_tab
      @selected_tab = :customers
    end
  
end