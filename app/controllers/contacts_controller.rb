class ContactsController < ApplicationController

   include APIHelperMethods
   include HelpdeskControllerMethods
   include ExportCsvUtil

   before_filter :redirect_to_mobile_url
   before_filter :clean_params, :only => [:update]
   before_filter :check_demo_site, :only => [:destroy,:update,:create]
   before_filter :set_selected_tab
   before_filter :check_agent_limit, :only =>  :make_agent
   before_filter :load_item, :only => [:edit, :update, :make_agent,:make_occasional_agent]
   before_filter :set_user_email, :only => :edit
   skip_before_filter :build_item , :only => [:new, :create]
   before_filter :set_mobile , :only => :show
   before_filter :check_parent, :only => :restore
   before_filter :fetch_contacts, :only => [:index]
   before_filter :set_native_mobile, :only => [:show, :index, :create, :destroy, :restore]
   
  def check_demo_site
    if AppConfig['demo_site'][Rails.env] == current_account.full_domain
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
        render :json => @contacts.as_json
      end
      format.atom do
        @contacts = @contacts.newest(20) #throws error
      end
      format.nmobile do
        array = []
        @contacts.each do |user|
          array << user.to_mob_json_search
        end
        render :json => array
      end
    end    
  end

  def new
    initialize_new_user
  end
  
  def quick_contact_with_company
    if initialize_and_signup!
        flash[:notice] = t(:'flash.contacts.create.success')
    else  
        check_email_exist
        flash[:notice] =  activerecord_error_list(@user.errors)      
    end
    redirect_to(company_url(@user.company || params[:id]))
  end
  
  def create   
    if initialize_and_signup!
      flash[:notice] = render_to_string(:partial => '/contacts/contact_notice', :formats => [:html], :locals => { :message => t('flash.contacts.create.success') } ).html_safe
      respond_to do |format|
        format.html { redirect_to contacts_url }
        format.xml  { render :xml => @user, :status => :created, :location => contacts_url(@user) }
        format.nmobile { 
            render :json => { :requester_id  => @user.id , :success => true , :success_message => t("flash.contacts.create.success") 
                                        }.to_json }
        format.json {
            render :json => @user.as_json
        }
        format.widget { render :action => :show, :layout => "widgets/contacts"}
        format.js
      end
    else
      check_email_exist
      respond_to do |format|
        format.html { render :action => :new}
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity} # bad request
        format.nmobile { render :json => { :error => true , :message => @user.errors }.to_json }
        format.json { render :json =>@user.errors, :status => :unprocessable_entity} #bad request
        format.nmobile { render :json => { :error => true , :message => @user.errors }.to_json }
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

  def hover_card_in_new_tab
    @user = current_account.all_users.find(params[:id])    
    render :partial => "hover_card", :locals => 
      {
        :new_tab => true
      }
  end

  def configure_export
    render :partial => "contacts/contact_export", :locals => {:csv_headers => EXPORT_CONTACT_FIELDS}
  end

  def export_csv
    csv_hash = params[:export_fields]
    export_contact_data csv_hash
  end
  
  def show
    email = params[:email]
    @user = nil # reset the user object.
    @user = current_account.user_emails.user_for_email(email) unless email.blank?
    @user = current_account.all_users.find(params[:id]) if @user.blank?
    @merged_user = @user.parent unless @user.parent.nil?
    Rails.logger.info "$$$$$$$$ -> #{@user.inspect}"
    respond_to do |format|
      format.html { 
        @total_user_tickets = current_account.tickets.permissible(current_user).requester_active(@user).visible
        @user_tickets = @total_user_tickets.newest(5).find(:all, :include => [:ticket_states,:ticket_status,:responder,:requester]) 
      }
      format.xml  { render :xml => @user.to_xml} # bad request
      format.json { render :json => @user.as_json }
      format.any(:mobile,:nmobile) { render :json => @user.to_mob_json }
    end
  end
  
  #probable dead code
  def delete_avatar
    load_item
    @user.avatar.destroy
    render :text => "success"
  end
  
  def update
    if @user.update_attributes(params[:user])
      respond_to do |format|
        flash[:notice] = render_to_string(:partial => '/contacts/contact_notice', :formats => [:html], :locals => { :message => t('merge_contacts.contact_updated') } ).html_safe
        format.html { redirect_to redirection_url }
        format.xml  { head 200}
        format.json { head 200}
      end
    else
      check_email_exist
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity} #Bad request
        format.json { render :json => @user.errors, :status => :unprocessable_entity}
      end
    end
  end

  def verify_email
    @user_mail = current_account.user_emails.find(params[:email_id])
    @user_mail.deliver_contact_activation_email
    @user_mail.user.reset_primary_email(params[:email_id]) if !@user_mail.user.active?
    flash[:notice] = t('merge_contacts.activation_sent')
    respond_to do |format|
      format.js
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
    items = current_account.companies.find(:all, 
                                            :conditions => ["name like ? ", "%#{params[:v]}%"], 
                                            :limit => 30)

    r = {:results => items.map {|i| {:id => i.id, :value => i.name} } }  
    respond_to do |format|
      format.json { render :json => r.to_json }
    end    
  end
 
  def contact_email
    email = params[:email]
    @user = current_account.user_emails.user_for_email(email) unless email.blank?
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
    @user.user_emails.build({:primary_role => true}) if current_account.features_included?(:contact_merge_ui)
    @user.time_zone = current_account.time_zone
    @user.language = current_account.language
  end

  def cname
      @cname ='user'
  end

  def check_parent
    @items.delete_if{ |item| !item.parent.nil? }
  end

  def scoper
    if !params[:tag].blank?
      tag = current_account.tags.find(params[:tag])
      tag.contacts
    elsif !params[:query].blank?
      query = params[:query]
      current_account.all_contacts.with_conditions(convert_query_to_conditions(query))
    else
      current_account.all_contacts
    end
  end

  def load_item
    @user = @item = scoper.find(params[:id])

    @item || raise(ActiveRecord::RecordNotFound)
  end

  def set_user_email
    @user.user_emails.build if current_account.features_included?(:contact_merge_ui) and @user.user_emails.blank?
  end
   
  def set_selected_tab
      @selected_tab = :customers
  end
  
  def check_email_exist
    if current_account.features_included?(:contact_merge_ui)
      @user.user_emails.each do |ue|
        if("has already been taken".eql?(ue.errors["email"]))
          @existing_user = current_account.user_emails.user_for_email(ue.email)
        end
      end
      @user.user_emails.build({:primary_role => true}) if @user.user_emails.blank?
    else
      if((@user.errors.messages[:base]).include? "Email has already been taken")
        @existing_user = current_account.all_users.find(:first, :conditions =>{:users =>{:email => @user.email}})
      end
    end
  end

 def check_agent_limit
    if current_account.reached_agent_limit? 
    flash[:notice] = t('maximum_agents_msg') 
    redirect_to :back 
   end
  end

  def redirection_url # Moved out to overwrite in Freshservice
    contacts_url
  end

  def clean_params
    if params[:user]
      params[:user].delete(:helpdesk_agent)
      params[:user].delete(:role_ids)
    end
  end

  private

    def initialize_and_signup!
      @user = current_account.users.new #by Shan need to check later  
      @user.signup!(params)
    end

    def get_formatted_message(exception)
      exception.message # TODO: Proper error reporting.
    end

    def fetch_contacts
       # connection_to_be_used =  params[:format].eql?("xml") ? "run_on_slave" : "run_on_master"
       # temp need to change...
       connection_to_be_used = "run_on_slave"
       per_page =  (params[:per_page].blank? || params[:per_page].to_i > 50) ? 50 :  params[:per_page]
       order_by =  (!params[:order_by].blank? && params[:order_by].casecmp("id") == 0) ? "Id" : "name"
       order_by = "#{order_by} DESC" if(!params[:order_type].blank? && params[:order_type].casecmp("desc") == 0)
       @sort_state = params[:state] || cookies[:contacts_sort] || 'verified'
       begin
         @contacts =   Sharding.send(connection_to_be_used.to_sym) do
          scoper.filter(params[:letter], params[:page],params.fetch(:state , @sort_state),per_page,order_by)
        end
      cookies[:contacts_sort] = @sort_state
      rescue Exception => e
        @contacts = {:error => get_formatted_message(e)}
      end
    end
end
