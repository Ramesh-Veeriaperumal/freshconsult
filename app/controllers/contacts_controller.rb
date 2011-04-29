class ContactsController < ApplicationController
  
   before_filter { |c| c.requires_permission :manage_tickets }
  
   include ModelControllerMethods
   before_filter :check_demo_site, :only => [:destroy,:update,:create]
   before_filter :check_user_limit, :only => :make_agent
   before_filter :set_selected_tab
   skip_before_filter :build_object , :only => :new
   
   def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = "Demo site doesn't have this access!"
      redirect_to :back
    end
  end
  
  
  
  
  def index
    
   
    respond_to do |format|
      format.html  do
        @contacts = scoper.filter(params[:letter],params[:page])
      end
      format.atom do
        @contacts = @contacts.newest(20)
      end
    end
    
  end

  def new
    @user = current_account.users.new
    @user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
    @user.avatar = Helpdesk::Attachment.new
    @user.time_zone = current_account.time_zone
  end
  
  def quick_customer
    build_object
    params[:user][:customer_id] = params[:customer_id]
    if build_and_save
        flash[:notice] = "The contact has been created and activation instructions sent to #{@user.email}!"
    else  
        check_email_exist
        flash[:notice] =  activerecord_error_list(@user.errors)        
    end
    customer = current_account.customers.find(params[:customer_id])
    redirect_to(customer_url(customer))
  end
  
  def create
    if build_and_save    
      flash[:notice] = "The contact has been created and activation instructions sent to #{@user.email}!"      
      redirect_to contacts_url
    else
      check_email_exist
      render :action => :new
    end
  end
  
  def build_and_save
    @user = current_account.users.new #by Shan need to check later  
    company_name = params[:user][:customer]    
    unless company_name.blank?      
      params[:user][:customer_id] = add_or_update_company   
    end
    logger.debug "build_save :: @user is :::#{@user.inspect}"
    @user.signup!(params)
  end
  
  def add_or_update_company
   
    company_name = params[:user][:customer]       
    customer = (current_account.customers.find_by_name(company_name))     
    if customer.nil? 
      @customer = current_account.customers.new(:name =>company_name)
      @customer.save
      customer = @customer
    end
    
    return customer.id
    
  end
  
  def show 
    @user = current_account.all_users.find(params[:id])
    @user_tickets_open_pending = Helpdesk::Ticket.requester_active(@user)
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
      check_email_exist
      render :action => 'edit'
    end
  end
  
  
   def destroy
   
      if @obj.respond_to?(:deleted)
        if @obj.update_attribute(:deleted, true)
           @restorable = true
           flash[:notice] = render_to_string(:partial => '/contacts/flash/delete_notice') 
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
      :partial => '/contacts/flash/restore_notice')
    redirect_to :back
  end
  
  def make_agent    
    @obj.update_attributes(:delete =>false   ,:user_role =>User::USER_ROLES_KEYS_BY_TOKEN[:poweruser])      
    @agent = current_account.agents.new
    @agent.user_id = @obj.id  
    if @agent.save        
      redirect_to @obj
    else
      redirect_to :back
    end    
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
      @obj = self.instance_variable_set('@user',  current_account.all_contacts.find(params[:id]))      
  end
  
    def check_user_limit
      redirect_to :back if current_account.reached_user_limit?
    end

   def check_email_exist
     if("has already been taken".eql?(@user.errors["email"]))        
           @existing_user = current_account.all_users.find(:first, :conditions =>{:users =>{:email => @user.email}})
     end    
   end

end
