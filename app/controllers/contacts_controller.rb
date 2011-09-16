class ContactsController < ApplicationController
  
   before_filter { |c| c.requires_permission :manage_tickets }
  
   include ModelControllerMethods
   before_filter :check_demo_site, :only => [:destroy,:update,:create]
   before_filter :check_agent_limit, :only => :make_agent
   before_filter :set_selected_tab
   skip_before_filter :build_object , :only => :new
   
   def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = t(:'flash.not_allowed_in_demo_site')
      redirect_to :back
    end
  end
  
  def index
    respond_to do |format|
      format.html do
        @contacts = scoper.filter(params[:letter],params[:page])
      end
      format.xml  do
        @contacts = scoper.all
       render :xml => @contacts.to_xml
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
        flash[:notice] = t(:'flash.contacts.create.success')
    else  
        check_email_exist
        flash[:notice] =  activerecord_error_list(@user.errors)        
    end
    customer = current_account.customers.find(params[:customer_id])
    redirect_to(customer_url(customer))
  end
  
  def create   
    if build_and_save    
      flash[:notice] = t(:'flash.contacts.create.success')
      respond_to do |format|
        format.html { redirect_to contacts_url }
        format.xml  { head 200 }
      end
    else
      check_email_exist
       respond_to do |format|
        format.html { render :action => :new}
        format.xml  { head :failed} # bad request
      end
    end
  end
  
  def build_and_save
    @user = current_account.users.new #by Shan need to check later  
    company_name = params[:user][:customer]    
    unless company_name.blank?      
     params[:user][:customer_id] = current_account.customers.find_or_create_by_name(company_name).id 
    end    
    @user.signup!(params)
  end
  
  def show 
    @user = current_account.all_users.find(params[:id])
    @user_tickets_open_pending = current_account.tickets.requester_active(@user).visible.newest(5)
    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @user.to_xml} # bad request
    end
  end
  
  def delete_avatar
    load_object
    @user.avatar.destroy
    render :text => "success"
  end
  
  def update    
    company_name = params[:user][:customer]
    unless company_name.blank?     
      @obj.customer_id = current_account.customers.find_or_create_by_name(company_name).id 
    else
      @obj.customer_id = nil
    end     
    if @obj.update_attributes(params[cname])
      respond_to do |format|
        format.html { redirect_to contacts_url }
        format.xml  { head 200}
      end
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      check_email_exist
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.xml  { head 400} #Bad request
      end
    end
  end  
  
   def destroy   
      if @obj.respond_to?(:deleted)
        if @obj.update_attribute(:deleted, true)
           @restorable = true
          
           respond_to do |format|
              format.html {  
                  flash[:notice] = render_to_string(:partial => '/contacts/flash/delete_notice') 
                  redirect_to redirect_url }
              format.xml  { head 200} 
           end
         else
           respond_to do |format|
              format.html { render :action => 'show' }
              format.xml  { head 400} #Bad request
           end
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
    
  def set_selected_tab
      @selected_tab = :customers
  end
 
  def load_object
      @obj = self.instance_variable_set('@user',  current_account.all_users.find(params[:id]))      
  end
  
  def build_object  
    @obj = self.instance_variable_set('@' + cname, current_account.all_users.new(params[cname]) )
  end
  
  def check_agent_limit
      redirect_to :back if current_account.reached_agent_limit?
  end

  def check_email_exist
    if("has already been taken".eql?(@user.errors["email"]))        
			@existing_user = current_account.all_users.find(:first, :conditions =>{:users =>{:email => @user.email}})
		end
	end

end
