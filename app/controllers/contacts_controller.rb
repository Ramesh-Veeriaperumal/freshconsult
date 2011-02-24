class ContactsController < ApplicationController
  
   before_filter { |c| c.requires_permission :manage_tickets }
  
 include ModelControllerMethods

  before_filter :check_user_limit, :only => :create 
  before_filter :set_selected_tab
  skip_before_filter :build_object , :only => :new
  
  
  def index
    
    @contacts = self.instance_variable_set('@' + self.controller_name,
    scoper.find(:all, :order => 'name' ))  
      
    
    respond_to do |format|
      format.html  do
        @contacts = scoper.search(params[:letter],params[:page])
      end
      format.atom do
        @contacts = @contacts.newest(20)
      end
    end
    
  end

  def new
    @user = current_account.users.new
    @user.role_token = 'customer'
    @user.avatar = Helpdesk::Attachment.new
  end
  
  def create
    
    @user = current_account.users.new #by Shan need to check later  

    company_name =params[:user][:customer]    
    unless company_name.empty?      
      params[:user][:customer_id]= add_or_update_company   
    end
    
    if @user.signup!(params)    
      flash[:notice] = "The contact has been created and activation instructions sent to #{@user.email}!"
      redirect_to contacts_url
    else
      render :action => :new
    end
  end
  
  def add_or_update_company
   
    company_name = params[:user][:customer]       
    cust_id = current_account.customers.find_by_name(company_name).id     
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
  
  def update
    
    company_name = params[:user][:customer]
    unless company_name.empty?     
      @obj.customer_id = add_or_update_company    
    else
      @obj.customer_id = nil
    end
     
    if @obj.update_attributes(params[cname])
      #flash[:notice] = "The #{cname.humanize.downcase} has been updated."
      redirect_to contacts_url
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      render :action => 'edit'
    end
  end
  
  
   def destroy
   
      if @obj.respond_to?(:deleted)
        if @obj.update_attribute(:deleted, true)
           @restorable = true
           flash[:notice] = render_to_string(:partial => '/helpdesk/shared/flash/delete_notice') 
           redirect_to redirect_url
         else
           render :action => 'show'
         end
         
      else
        if item.destroy
          flash[:notice] = "The #{cname.humanize.downcase} has been deleted."
          redirect_back_or_default redirect_url
        else
          render :action => 'show'
        end
      end
   
  end

  def restore
   
    @obj.update_attribute(:deleted, false)
    
    flash[:notice] = render_to_string(
      :partial => '/helpdesk/shared/flash/restore_notice')
    redirect_to :back
  end
  
  def autocomplete
   
     items = current_account.customers.find(:all, 
                                            :conditions => ["name like ? ", "%#{params[:v]}%"], 
                                            :limit => 30)

    r = {:results => items.map {|i| {:id => i.id, :value => i.name} } }  
    respond_to do |format|
      format.json { render :json => r.to_json }
    end
    
  end
 

protected

 def cname
      @cname ='user'
 end
 def scoper
      current_account.contacts
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
 
  def load_object
      @obj = self.instance_variable_set('@user',  scoper.find(params[:id]))
  end
  
  

end
