class ContactsController < ApplicationController

   include APIHelperMethods
   include HelpdeskControllerMethods
   include ExportCsvUtil
   include UserHelperMethods
   include Redis::RedisKeys
   include Redis::OthersRedis
   include Export::Util

   before_filter :redirect_to_mobile_url
   before_filter :redirect_old_ui_routes, only: [:index, :show, :new, :edit]
   before_filter :set_ui_preference, :only => [:show]
   before_filter :clean_params, :only => [:update, :update_contact, :update_description_and_tags]
   before_filter :check_demo_site, :only => [:destroy,:update,:update_contact, :update_description_and_tags, :create, :create_contact]
   before_filter :set_selected_tab
   before_filter(:only => [:make_occasional_agent]) { |c| c.requires_this_feature :occasional_agent }
   before_filter :load_item, :only => [:edit, :update, :update_contact, :update_description_and_tags, :make_agent,:make_occasional_agent,
                                        :change_password, :update_password]
   before_filter :can_change_password?, :only => [:change_password, :update_password]
   before_filter :load_password_policy, :only => [:change_password]
   before_filter :check_agent_limit, :can_make_agent, :only => [:make_agent]

   around_filter :run_on_slave, :only => [:index]

   skip_before_filter :build_item , :only => [:new, :create]
   before_filter :set_mobile , :only => :show
   before_filter :init_user_email, :only => :edit
   before_filter :load_companies, :only => :edit
   before_filter :check_parent, :only => :restore
   before_filter :validate_state_param, :fetch_contacts, :only => [:index]
   before_filter :set_native_mobile, :only => [:show, :index, :create, :destroy, :restore,:update]
   before_filter :set_required_fields, :only => [:create_contact, :update_contact]
   before_filter :set_validatable_custom_fields, :only => [:create, :update, :create_contact, :update_contact]
   before_filter :restrict_user_primary_email_delete, :only => :update_contact
   before_filter :check_agent_deleted_forever, :only => [:restore]
   before_filter :export_limit_reached?, only: [:export_csv]

  def index
    respond_to do |format|
      format.html do
        tag_ids = current_account.tag_uses.where("taggable_type = 'User'").pluck(:tag_id).uniq
        @tags = current_account.tags.where("id in (?)", tag_ids).all
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
      flash[:notice] = @flash_notice || render_to_string(:partial => '/contacts/contact_notice', :formats => [:html], :locals => { :message => t('flash.contacts.create.success') } ).html_safe
      respond_to do |format|
        format.html { redirect_to redirection_url }
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
        format.html { render :action => :new }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity} # bad request
        format.nmobile { render :json => { :error => true , :message => @user.errors.fd_json }.to_json }
        format.json { render :json =>@user.errors.fd_json, :status => :unprocessable_entity} #bad request
        format.widget { render :action => :show}
        format.js
      end
    end
  end

  def create_contact # new method to implement dynamic validations, as many forms post to create action
    @flash_notice = t('flash.contacts.create.success')
    create
  end

  def change_password
    #do nothing
  end

  def update_password

    if params[:user][:password] != params[:user][:password_confirmation]
      flash[:error] = t(:'flash.password_resets.update.password_does_not_match')
      redirect_to change_password_contact_path(@user)
    else
      @user.password = params[:user][:password]
      @user.password_confirmation = params[:user][:password_confirmation]
      @user.active = true #by Shan need to revisit..

      if @user.save
        @user.reset_perishable_token!
        flash[:notice] = t(:'flash.password_resets.update.success')
        redirect_to contact_path(@user)
      else
        flash[:error] = @user.errors.full_messages.join("<br/>").html_safe
        redirect_to change_password_contact_path(@user)
      end
    end

  end

  def unblock
    ids = params[:ids] || Array(params[:id])

    if ids
      User.where(account_id: current_account.id, id: ids)
      .where('blocked_at IS NULL OR blocked_at <= ?', (Time.now+5.days).to_s(:db))
      .where('deleted_at IS NULL OR deleted_at <= ?', (Time.now+5.days).to_s(:db))
      .update_all_with_publish({ blocked: false, whitelisted: true, deleted: false, blocked_at: nil }, {})
      begin
        Tickets::RestoreSpamTicketsWorker.perform_async(:user_ids => ids)
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

  def contact_details_for_ticket
    user_detail = {}
    search_options = {:email => params[:email], :phone => params[:phone]}
    @user = current_account.all_users.find_by_an_unique_id(search_options)
    user_detail = {:name => @user.name, :avatar => view_context.user_avatar(@user), :title => @user.job_title, :email => @user.email, :phone => @user.phone, :mobile => @user.mobile} if @user
    render :json => user_detail.to_json
  end

  def configure_export
    render :partial => "contacts/contact_export", :locals => {:csv_headers => export_customer_fields("contact")}
  end

  def export_csv
    portal_url = main_portal? ? current_account.host : current_portal.portal_url
    create_export 'contact'
    file_hash @data_export.id
    export_worker_params = { csv_hash: params[:export_fields],
                             user: current_user.id,
                             portal_url: portal_url,
                             data_export: @data_export.id }
    Export::ContactWorker.perform_async(export_worker_params)
    flash[:notice] = t(:'contacts.export_start')
    redirect_to :back
  end

  def show
    email = params[:email]
    @user = nil # reset the user object.
    @user = current_account.user_emails.user_for_email(email) unless email.blank?
    @user = current_account.all_users.find(params[:id]) if @user.blank?

    if @user.agent_deleted_forever?
      error_message = { :errors => { :message => t('contact_agent_deleted_forever') }}
      flash[:error] = t('contact_agent_deleted_forever')
      respond_to do |format|
        format.html { redirect_to contacts_path }
        format.json { render :json => error_message, :status => :bad_request}
        format.xml { render :xml => error_message.to_xml , :status => :bad_request}
      end
      return
    end

    load_companies

    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @user.to_xml} # bad request
      format.json { render :json => @user.as_json }
      format.any(:mobile,:nmobile) { render :json => @user.to_mob_json }
    end
  end

  def view_conversations
    @user = current_account.all_users.find(params[:id])
    types = ["all", "tickets", "forums", "archived_tickets"]
    conversation_type = types.include?(params[:type]) ? params[:type] : types[0]

    if conversation_type == types[0] || conversation_type == types[1]
      define_contact_tickets
    elsif conversation_type == types[3] && current_account.features_included?(:archive_tickets)
      define_contact_archive_tickets
    end

    respond_to do |format|
      format.html {
        render :partial => "contacts/view_conversations_#{conversation_type}"
      }
    end
  end

  def update
    @user.update_companies(params)
    filtered_params = params[:user].reject { |k| ["added_list", "removed_list"].include?(k) }
    @user.save_tags
    if @user.update_attributes(filtered_params)
      respond_to do |format|
        flash[:notice] = t('merge_contacts.contact_updated')
        format.html { redirect_to redirection_url }
        format.xml  { head 200 }
        format.json { head 200}
        format.nmobile { render :json => { :success => true } }
      end
    else
      check_email_exist
      load_companies
      respond_to do |format|
        format.html { render :action => :edit }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity} #Bad request
        format.json { render :json => @item.errors.fd_json, :status => :unprocessable_entity}
        format.nmobile { render :json => { :success => false, :err => @item.errors.full_messages ,:status => :unprocessable_entity} }
      end
    end
  end

  def update_contact # new method to implement dynamic validations, so as not to impact update API
    update
  end

  def update_description_and_tags
    begin
      @user.save_tags
      if @user.update_attributes(params[:user])
        updated_tags = @user.tags.collect {|tag| {:id => tag.id, :name => tag.name}}
        respond_to do |format|
          format.html { redirect_to contact_path(@user.id) }
          format.json { render :json => updated_tags, :status => :ok}
        end
      else
        respond_to do |format|
          format.html {
            define_contact_properties
            render :show
          }
          format.json { render :json => @item.errors.fd_json, :status => :unprocessable_entity}
        end
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      updated_tags = @user.tags.collect {|tag| {:id => tag.id, :name => tag.name}}
      respond_to do |format|
        format.json { render :json => updated_tags, :status => :ok}
      end
    end
  end

  def verify_email
    @user_mail = current_account.user_emails.find(params[:email_id])
    @user_mail.user.reset_primary_email(params[:email_id])
    @user_mail.user.save
    flash[:notice] = t('merge_contacts.activation_sent')
    respond_to do |format|
      format.js
    end
  end

  def cname
    @cname ='user'
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
        agent = Agent.find_by_user_id(@item.id)
        format.html { flash[:notice] = t(:'flash.contacts.to_agent')
          redirect_to @item }
        format.xml  { render :xml => agent, :status => 200 }
        format.json {render :json => agent.as_json,:status => 200}
      else
        format.html { redirect_to :back }
        format.xml  { render :xml => @item.errors, :status => 500 }
        format.json { render :json => @item.errors.fd_json,:status => 500 }
      end
    end
  end

  def autocomplete
    items = current_account.companies.where(['name like ? ', "%#{params[:v]}%"]).limit(30).to_a
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
    @user.user_emails.build({:primary_role => true})
    @user.time_zone = current_account.time_zone
    @user.language = current_account.language
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
      if query.include?('customer_id') && Account.current.multiple_user_companies_enabled?
        current_account.all_contacts.with_contractors(convert_query_to_conditions(query))
      else
        current_account.all_contacts.with_conditions(convert_query_to_conditions(query))
      end
    else
      current_account.all_contacts
    end
  end

  def load_item
    @user = @item = scoper.find(params[:id])

    @item || raise(ActiveRecord::RecordNotFound)
  end

  def set_selected_tab
      @selected_tab = :customers
  end

  def check_email_exist
    @user.user_emails.each do |ue|
      if(ue.new_record? and @user.errors[:"user_emails.email"].include? "has already been taken")
        @existing_user ||= current_account.user_emails.user_for_email(ue.email)
      end
    end
    init_user_email
  end

 def check_agent_limit
    if current_account.reached_agent_limit?
      error_message = { :errors => { :message => t('maximum_agents_msg') }}
      respond_to do |format|
        format.html {
          flash[:notice] = t('maximum_agents_msg')
          redirect_to :back
        }
        format.json { render :json => error_message, :status => :bad_request}
        format.xml { render :xml => error_message.to_xml , :status => :bad_request}
      end
    end
  end

  def check_agent_deleted_forever
    agent_deleted_forever = @items.any? { |c| c.agent_deleted_forever? }
    if agent_deleted_forever
      error_message = { :errors => { :message => t('contact_agent_deleted_forever') }}
      flash[:error] = t('contact_agent_deleted_forever')
      respond_to do |format|
        format.html { redirect_to contacts_path }
        format.json { render :json => error_message, :status => :bad_request}
        format.xml { render :xml => error_message.to_xml , :status => :bad_request}
      end
    end
  end

  def can_make_agent
    unless @item.has_email?
      error_message = { :errors => { :message => t('contact_without_email_id') }}
      respond_to do |format|
          format.json { render :json => error_message, :status => :bad_request}
          format.xml { render :xml => error_message.to_xml , :status => :bad_request}
      end
    end
  end

  def redirection_url # Moved out to overwrite in Freshservice
    contact_url(@user)
  end

  private

    def set_required_fields
      @user ||= current_account.users.new
      @user.required_fields = { :fields => current_account.contact_form.agent_required_contact_fields,
                                :error_label => :label }
    end

    def define_contact_tickets
      @total_user_tickets = current_account.tickets.permissible(current_user).requester_active(@user).visible.newest(11).includes([:ticket_states, :ticket_status, :responder, :requester]).to_a
      @total_user_tickets_size = @total_user_tickets.length
      @user_tickets = @total_user_tickets.take(10)
    end

    def define_contact_archive_tickets
      if current_account.features_included?(:archive_tickets)
        @total_archive_user_tickets = current_account.archive_tickets.permissible(current_user).requester_active(@user).newest(11).includes([:responder, :requester]).to_a
        @total_archive_user_tickets_size = @total_archive_user_tickets.length
        @user_archive_tickets = @total_archive_user_tickets.take(10)
      end
    end

    def define_contact_properties
      @merged_user = @user.parent unless @user.parent.nil?
      define_contact_tickets
      define_contact_archive_tickets
    end

    def get_formatted_message(exception)
      exception.message # TODO: Proper error reporting.
    end

    def validate_state_param
      #whitelisting contacts filter param
      render :nothing => true, :status => 400 if params[:state] && !User::USER_FILTER_TYPES.include?(params[:state])
    end

    def export_limit_reached?
      if DataExport.contact_export_limit_reached?
        flash[:notice] = I18n.t('export_data.customer_export.limit_reached')
        redirect_to contacts_path
      end
    end

    def fetch_contacts
      # connection_to_be_used =  params[:format].eql?("xml") ? "run_on_slave" : "run_on_master"
      # temp need to change...
      per_page =  (params[:per_page].blank? || params[:per_page].to_i > 50) ? 50 :  params[:per_page]
      order_by =  (!params[:order_by].blank? && params[:order_by].casecmp("id") == 0) ? "Id" : "name"
      order_by = "#{order_by} DESC" if(!params[:order_type].blank? && params[:order_type].casecmp("desc") == 0)
      @sort_state = params[:state] || cookies[:contacts_sort] || 'all'
      begin
        @contacts ||= scoper.filter(params[:letter],
                                  params[:page],
                                  params.fetch(:state , @sort_state),
                                  per_page,order_by).preload(:avatar, :companies, :default_user_company).all
        @contacts_count ||= @contacts.length
        cookies[:contacts_sort] = @sort_state
      rescue Exception => e
       @contacts = {:error => get_formatted_message(e)}
      end
    end

    def init_user_email
      @item ||= @user
      @item.user_emails.build({:primary_role => true, :verified => @item.active? }) if @item.user_emails.empty?
    end

    def load_companies
      if current_user.has_multiple_companies_feature?
        @user_companies = @user.user_companies.preload(:company).to_a
        default_index = @user_companies.find_index { |uc| uc.default }
        @user_companies.insert(0, @user_companies.delete_at(default_index)) if default_index
        @selected_companies = @user_companies.map(&:company)
      end
    end

    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end

    def load_password_policy
      @password_policy = @user.agent? ? current_account.agent_password_policy : current_account.contact_password_policy
    end

    def can_change_password?
      redirect_to helpdesk_dashboard_url unless @user.allow_password_update?
    end

    def restrict_user_primary_email_delete
      params[:user][:user_emails_attributes].each do |key, value|
        if params[:user][:user_emails_attributes][key]["primary_role"]== "1"
          params[:user][:user_emails_attributes][key]["_destroy"] = false
        end
      end
    end
end
