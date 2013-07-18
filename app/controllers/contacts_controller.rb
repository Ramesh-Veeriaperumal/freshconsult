class ContactsController < ApplicationController

   include APIHelperMethods
   include HelpdeskControllerMethods
   include ExportCsvUtil

   before_filter :redirect_to_mobile_url
   before_filter :check_demo_site, :only => [:destroy,:update,:create]
   before_filter :set_selected_tab
   before_filter :check_agent_limit, :only =>  :make_agent
   before_filter :load_item, :only => [:edit, :update, :make_agent,:make_occasional_agent]
   skip_before_filter :build_item , :only => [:new, :create]
   before_filter :set_mobile , :only => :show
   before_filter :fetch_contacts, :only => [:index]
  
   
   def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = t(:'flash.not_allowed_in_demo_site')
      redirect_to :back
    end
  end
  
  def index
    
    respond_to do |format|
      format.html do
        @tags = current_account.tags.with_taggable_type(User.to_s)
      end
      format.xml  do
        render :xml => @contacts.to_xml(:root => "users")
      end

      format.json  do
        render :json => @contacts.to_json({:except=>[:account_id] ,:only=>[:id,:name,:email,:created_at,:updated_at,:active,:job_title,
                    :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                    :helpdesk_agent,:fb_profile_id,:external_id,:language,:address,:customer_id] })#avoiding the secured attributes like tokens
      end
      format.atom do
        @contacts = @contacts.newest(20)
      end
    end    
  end

  def new
    initialize_new_user
  end
  
  def quick_customer
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
        format.xml  { render :xml => @user, :status => :created, :location => contacts_url(@user) }
        format.json {
            render :json => @user.to_json({:except=>[:account_id] ,:only=>[:id,:name,:email,:created_at,:updated_at,:active,:job_title,
:phone,:mobile,:twitter_id,:description,:time_zone,:deleted,:fb_profile_id,:external_id,:language,:address,:customer_id] })#avoiding the secured attributes like tokens
        }
        format.widget { render :action => :show, :layout => "widgets/contacts"}
        format.js
      end
    else
      check_email_exist
      respond_to do |format|
        format.html { render :action => :new}
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity} # bad request
        format.json { render :json =>@user.errors, :status => :unprocessable_entity} #bad request
        format.widget { render :action => :show}
        format.js
      end
    end
  end

  def unblock
    ids = params[:ids] || Array(params[:id])
    if ids
      User.update_all({ :blocked => false, :whitelisted => true,:deleted => false, :blocked_at => nil }, 
        [" id in (?) and (blocked_at IS NULL OR blocked_at <= ?) and (deleted_at IS NULL OR deleted_at <= ?) and account_id = ? ",
         ids, (Time.now+5.days).to_s(:db), (Time.now+5.days).to_s(:db), current_account.id])
      begin
        Resque.enqueue(Workers::RestoreSpamTickets, :user_ids => ids)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      flash[:notice] = t(:'flash.contacts.whitelisted')
    end
    redirect_to contacts_path and return if params[:ids]
    redirect_to contact_path and return if params[:id]
  end

  def hover_card
    @user = current_account.all_users.find(params[:id])    
    render :partial => "hover_card"
  end

  def configure_export
    render :partial => "contacts/contact_export", :locals => {:csv_headers => export_contact_fields}
  end

  def export_csv
    csv_hash = params[:export_fields]
    export_contact_data csv_hash
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
    email = params[:email]
    @user = nil # reset the user object.
    @user = current_account.all_users.find_by_email(email) unless email.blank?
    @user = current_account.all_users.find(params[:id]) if @user.blank?
    Rails.logger.info "$$$$$$$$ -> #{@user.inspect}"
    @user_tickets = current_account.tickets.requester_active(@user).visible.newest(5).find(:all, 
      :include => [ :ticket_states,:ticket_status,:responder,:requester ])
    
    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @user.to_xml} # bad request
      format.json { render :json => @user.to_json({:only=>[:id,:name,:email,:created_at,:updated_at,:active,:job_title,
                    :phone,:mobile,:twitter_id, :description,:time_zone,:deleted,
                    :fb_profile_id,:external_id,:language,:address,:customer_id] })#avoiding the secured attributes like tokens
                  }
      format.mobile { render :json => @user.to_mob_json }
    end
  end
  
  def delete_avatar
    load_item
    @user.avatar.destroy
    render :text => "success"
  end
  
  def update    
    company_name = params[:user][:customer]
    unless company_name.blank?     
      @item.customer_id = current_account.customers.find_or_create_by_name(company_name).id 
    else
      @item.customer_id = nil
    end
    @item.update_tag_names(params[:user][:tags]) # update tags in the user object
    if @item.update_attributes(params[cname])
      respond_to do |format|
        format.html { redirect_to contacts_url }
        format.xml  { head 200}
        format.json { head 200}
      end
    else
      check_email_exist
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity} #Bad request
        format.json { render :json => @item.errors, :status => :unprocessable_entity}
      end
    end
  end
  
  def make_occasional_agent
    respond_to do |format|
      if @item.make_agent(:occasional => true)
        format.html { flash[:notice] = t(:'flash.contacts.to_agent') 
          redirect_to @item }
        format.xml  { render :xml => @item, :status => 200 }
      else
        format.html { redirect_to :back }
        format.xml  { render :xml => @item.errors, :status => 500 }
      end   
    end
  end
  
  def make_agent
    respond_to do |format|
      if @item.make_agent        
        format.html { flash[:notice] = t(:'flash.contacts.to_agent') 
          redirect_to @item }
        format.xml  { render :xml => @item, :status => 200 }
      else
        format.html { redirect_to :back }
        format.xml  { render :xml => @item.errors, :status => 500 }
      end   
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
 
  def contact_email
    email = params[:email]
    @user = current_account.all_users.find_by_email(email) unless email.blank?
    puts "@user #{@user}"
    if @user.blank?
      initialize_new_user
      render :new, :layout => "widgets/contacts"
    else
      render :show, :layout => "widgets/contacts"
    end
  end

protected

  def initialize_new_user
    @user = current_account.users.new
    @user.helpdesk_agent = false
    @user.avatar = Helpdesk::Attachment.new
    @user.time_zone = current_account.time_zone
    @user.language = current_account.language
  end

  def cname
      @cname ='user'
  end

  def scoper
    if !params[:tag].blank?
      tag = current_account.tags.find(params[:tag])
      tag.contacts
    elsif !params[:query].blank?
      query = params[:query]
      current_account.contacts.with_conditions(convert_query_to_conditions(query))
    else
      current_account.all_contacts
    end
  end
   
  def set_selected_tab
      @selected_tab = :customers
  end
  
  def check_email_exist
    if("has already been taken".eql?(@user.errors["email"]))        
			@existing_user = current_account.all_users.find(:first, :conditions =>{:users =>{:email => @user.email}})
		end
 end

 def check_agent_limit
    if current_account.reached_agent_limit? 
    flash[:notice] = t('maximum_agents_msg') 
    redirect_to :back 
   end
  end

  private

    def get_formatted_message(exception)
      exception.message # TODO: Proper error reporting.
    end

    def fetch_contacts
       connection_to_be_used =  params[:format].eql?("xml") ? "run_on_slave" : "run_on_master"  
       begin
         @contacts =   Sharding.send(connection_to_be_used.to_sym) do
          scoper.filter(params[:letter], params[:page], params.fetch(:state, "verified"))
        end
      rescue Exception => e
        @contacts = {:error => get_formatted_message(e)}
      end
    end
end
