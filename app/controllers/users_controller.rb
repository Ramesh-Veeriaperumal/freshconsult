class UsersController < ApplicationController 
  include ModelControllerMethods

  before_filter :check_user_limit, :only => :create
  #before_filter :require_no_user, :only => [:new, :create] #by Shan need to check later
  #before_filter :require_user, :only => [:show, :edit, :update]
  before_filter :set_selected_tab
    
  def new
    @user.role_token = 'customer'
    @user.avatar = Helpdesk::Attachment.new
  end
  
  def create
    
    @user = current_account.users.new #by Shan need to check later
    
    company_id = add_or_update_company    
    params[:user][:customer_id]=company_id
    
    if @user.signup!(params)
      #@user.deliver_activation_instructions! #Have moved it to signup! method in the model itself.
      flash[:notice] = "The user has been created and activation instructions sent to #{@user.email}!"
      redirect_to users_url
    else
      render :action => :new
    end
  end
  
  def add_or_update_company
   
    company_name = params[:user][:customer]    
    cust_id = Customer.find_by_name(company_name)
    
    if cust_id.nil?      
      @customer = current_account.customers.new(:name =>company_name)
      @customer.save
      cust_id = @customer.id
    end
    
    return cust_id
    
  end
  
  def show
    @user = User.find(params[:id])
  end
  
  def delete_avatar
    load_object
    @user.avatar.destroy
    render :text => "success"
  end

 
  protected
  
    def scoper
      current_account.users.contacts
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