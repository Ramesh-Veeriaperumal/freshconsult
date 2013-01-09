require 'fastercsv'
require 'html2textile'

class Helpdesk::TicketsController < ApplicationController  
  
  include ActionView::Helpers::TextHelper
  include ParserUtil
  include HelpdeskControllerMethods  
  include Helpdesk::TicketActions
  include Search::TicketSearch
  include Helpdesk::Ticketfields::TicketStatus
  include RedisKeys
  include Helpdesk::AdjacentTickets
  include Helpdesk::Activities

  before_filter :set_mobile, :only => [:index, :show, :details, :update, :create, :execute_scenario, :assign, :spam, :get_agents ]
  before_filter :set_show_version
  before_filter :check_user, :load_installed_apps, :only => [:show, :details, :forward_conv]


  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_cached_ticket_filters, :load_ticket_filter , :only => [:index, :filter_options]
  before_filter :clear_filter, :only => :index
  before_filter :add_requester_filter , :only => [:index, :user_tickets]
  before_filter :cache_filter_params, :only => [:custom_search]
  before_filter :disable_notification, :if => :notification_not_required?
  after_filter  :enable_notification, :if => :notification_not_required?
  before_filter :set_selected_tab

  layout :choose_layout 
  
  before_filter :load_multiple_items, :only => [ :destroy, :restore, :spam, :unspam, :assign, 
    :close_multiple ,:pick_tickets, :delete_forever ]  
  
  skip_before_filter :load_item
  alias :load_ticket :load_item
  before_filter :load_ticket, :verify_permission, :only => [:show, :details, :edit, :update, :execute_scenario, :close, :change_due_by, :print, :clear_draft, :save_draft, :draft_key, :get_ticket_agents, :quick_assign, :prevnext, :activities, :status]

  before_filter :load_flexifield ,    :only => [:execute_scenario]
  before_filter :set_date_filter ,    :only => [:export_csv]
  before_filter :csv_date_range_in_days , :only => [:export_csv]
  before_filter :check_ticket_status, :only => [:update]
  before_filter :set_default_filter , :only => [:custom_search, :export_csv]

  before_filter :load_email_params, :only => [:show, :details, :reply_to_conv, :forward_conv]
  before_filter :load_conversation_params, :only => [:reply_to_conv, :forward_conv]
  before_filter :load_reply_to_all_emails, :only => [:show, :details, :reply_to_conv]

  after_filter  :set_adjacent_list, :only => [:index, :custom_search]

  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR
  
 
  def user_ticket
    if params[:email].present?
      @user = current_account.users.find_by_email(params[:email])
    elsif params[:external_id].present?
      @user = current_account.users.find_by_external_id(params[:external_id])
    end
    if !@user.nil?
      @tickets =  current_account.tickets.visible.requester_active(@user).paginate(:page => 
                    params[:page],:per_page => 30)
    else
      @tickets = []
    end
    respond_to do |format|
      format.xml do
        render :xml => @tickets.to_xml
      end
      format.json do
        render :json => @tickets.to_json
      end
    end
  end
  
  def index

    #For removing the cookie that maintains the latest custom_search response to be shown while hitting back button
    cookies.delete(:ticket_list_updated) 
    tkt = current_account.tickets.permissible(current_user)
    @items = tkt.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter') 

    if @items.empty? && !params[:page].nil? && params[:page] != '1'
      params[:page] = '1'  
      @items = tkt.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter') 
    end
    respond_to do |format|      
      format.html  do
        @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
        @current_options = @ticket_filter.query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
        @show_options = show_options
        @current_view = @ticket_filter.id || @ticket_filter.name unless params[:requester_id]
        @is_default_filter = (!is_num?(@template.current_filter))
        # if request.headers['X-PJAX']
        #   render :layout => "maincontent"
        # end
      end
      
      format.xml do
        render :xml => @response_errors.nil? ? @items.to_xml : @response_errors.to_xml(:root => 'errors')
      end

      format.json do
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          json = "["; sep=""
          @items.each { |tic| 
            #Removing the root node, so that it conforms to JSON REST API standards
            # 19..-2 will remove "{helpdesk_ticket:" and the last "}"
            json << sep + tic.to_json({}, false)[19..-2]; sep=","
          }
          render :json => json + "]"
        end
      end
      
      format.mobile do 
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          json = "["; sep=""
          @items.each { |tic| 
            #Removing the root node, so that it conforms to JSON REST API standards
            # 19..-2 will remove "{helpdesk_ticket:" and the last "}"

            json << sep + tic.to_json({
              :except => [ :description_html, :description ],
              :methods => [ :status_name, :priority_name, :source_name, :requester_name,
                            :responder_name, :need_attention, :pretty_updated_date ]
            }, false)[19..-2]; sep=","
          }
          render :json => json + "]"
        end
      end
    end
  end

  
  def filter_options
    @current_options = @ticket_filter.query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
    @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
    @show_options = show_options
    @is_default_filter = (!is_num?(@template.current_filter))
    @current_view = @ticket_filter.id || @ticket_filter.name
    render :partial => "helpdesk/shared/filter_options", :locals => { :current_filter => @ticket_filter }
  end

  def latest_ticket_count    
    index_filter =  current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(params)       
    ticket_count =  current_account.tickets.permissible(current_user).latest_tickets(params[:latest_updated_at]).count(:id, :conditions=> index_filter.sql_conditions)

    respond_to do |format|
      format.html do
        render :text => ticket_count
      end
    end
  end
  
  def user_tickets
    @items = current_account.tickets.permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')

    respond_to do |format|
      format.json do
        render :json => @items.to_json
      end

      format.widget do
        render :layout => "widgets/contacts"    
      end
    end
    
  end

  def view_ticket
    if params['format'] == 'widget'
      @ticket = current_account.tickets.find_by_display_id(params[:id]) # using find_by_id(instead of find) to avoid exception when the ticket with that id is not found.
      @item = @ticket
      if @ticket.blank?
        @item = Helpdesk::Ticket.new
        render :new, :layout => "widgets/contacts"
      else
        if verify_permission
          @ticket_notes = @ticket.conversation
          render :layout => "widgets/contacts"
        else
          @no_auth = true
          render :layout => "widgets/contacts"
        end
      end
    end
  end

  def custom_view_save
     render :partial => "helpdesk/tickets/customview/new"
  end
  
  def custom_search
    @items = current_account.tickets.permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    render :partial => "custom_search"
  end
  
  def show
    @to_emails = @ticket.to_emails

    @draft = get_key(draft_key)

    @subscription = current_user && @item.subscriptions.find(
      :first, 
      :conditions => {:user_id => current_user.id})
      
    respond_to do |format|
      format.html  {
        if @new_show_page
          @ticket_notes.reverse!
          @ticket_notes_total = @ticket.conversation_count

          render :action => "details"
        end
      }
      format.atom
      format.xml  { 
        render :xml => @item.to_xml  
      }
      format.json {
        render :json => @item.to_json
      }
      format.js
      format.mobile {
        render :json => @item.to_mob_json
      }
    end
  end
  

  def details
    @to_emails = @ticket.to_emails

    @draft = get_key(draft_key)

    @subscription = current_user && @item.subscriptions.find(
      :first, 
      :conditions => {:user_id => current_user.id})
      
    respond_to do |format|
      format.html  {
        
      }
      format.atom
      format.xml  { 
        render :xml => @item.to_xml  
      }
      format.json {
        render :json => @item.to_json
      }
      format.js
      format.mobile {
        render :json => @item.to_mob_json
      }
    end
  end
  
  def prevnext
    @previous_ticket = find_adjacent(:prev)
    @next_ticket = find_adjacent(:next)
  end
  
  def update
    old_item = @item.clone
    #old_timer_count = @item.time_sheets.timer_active.size -  we will enable this later
    if @item.update_attributes(params[nscname])

      update_tags
      #flash[:notice] = flash[:notice].chomp(".")+"& \n"+ t(:'flash.tickets.timesheet.timer_stopped') if ((old_timer_count - @item.time_sheets.timer_active.size) > 0)
      respond_to do |format|
        format.html { 
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to item_url 
        }
        format.mobile { 
          render :json => { :success => true, :item => @item }.to_json 
        }
        format.xml { 
          render :xml => @item.to_xml({:basic => true})
        }
        format.json { 
          render :json => request.xhr? ? { :success => true }.to_json  : @item.to_json({:basic => true}) 
        }
      end
    else
      respond_to do |format|
        format.html { edit_error }
        format.json {
          result = {:errors=>@item.errors.full_messages }
          render :json => result.to_json
        }
        format.mobile { 
          render :json => { :failure => true, :errors => edit_error }.to_json 
        }
        format.json { 
          render :json => { :failure => true, :errors => edit_error }.to_json 
        }
        format.xml {
          render :xml =>@item.errors
        }
      end
    end
  end

  def assign
    user = params[:responder_id] ? User.find(params[:responder_id]) : current_user 
    assign_ticket user
    
    flash[:notice] = render_to_string(
      :inline => t("helpdesk.flash.assignedto", :tickets => get_updated_ticket_count, 
                                                :username => user.name ))


    respond_to do |format|
      format.html {
        if user === current_user && @items.size == 1
          redirect_to helpdesk_ticket_path(@items.first)
        else
          redirect_to :back
        end
      }
      format.xml { render :xml => @items.to_xml({:basic=>true}) }
      format.json { render :json => @items.to_json({:basic=>true}) }
    end

  end
  
  def close_multiple
    status_id = CLOSED       
    @items.each do |item|
      item.update_attributes(:status => status_id)
    end

    respond_to do |format|    
      format.html {
        flash[:notice] = render_to_string(
            :inline => t("helpdesk.flash.tickets_closed", :tickets => get_updated_ticket_count ))
          redirect_to :back
        }
        format.xml {  render :xml =>@items.to_xml({:basic=>true}) }
        format.json {  render :json =>@items.to_json({:basic=>true}) }

    end
  end
 
  def pick_tickets
    assign_ticket current_user
    flash[:notice] = render_to_string(
        :inline => t("helpdesk.flash.assigned_to_you", :tickets => get_updated_ticket_count ))
    respond_to do |format|
      format.html{ redirect_to :back }
      format.xml { render :xml => @items.to_xml({:basic=>true}) }
      format.json { render :json=>@items.to_json({:basic=>true}) }
    end
  end
  
  def execute_scenario 
    va_rule = current_account.scn_automations.find(params[:scenario_id])    
    va_rule.trigger_actions(@item)
    update_custom_field @item    
    @item.save
    @item.create_activity(current_user, 'activities.tickets.execute_scenario.long', 
      { 'scenario_name' => va_rule.name }, 'activities.tickets.execute_scenario.short')

    respond_to do |format|
      format.html { 
        flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice', 
                                      :locals => { :actions_executed => Va::Action.activities, :rule_name => va_rule.name })
        redirect_to :back 
      }
      format.xml { render :xml => @item, :status=>:success }
      format.json { render :json => @item, :status=>:success }  
      format.js { 
        flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice', 
                                      :locals => { :actions_executed => Va::Action.activities, :rule_name => va_rule.name })
      }
      format.mobile { 
        render :json => {:success => true, :id => @item.id, :actions_executed => Va::Action.activities, :rule_name => va_rule.name }.to_json 
      }
    end
  end 
  
  def mark_requester_deleted(item,opt)
    req = item.requester
    req.deleted = opt
    req.save if req.customer?
  end

  def spam
    req_list = []
    @items.each do |item|
      item.spam = true 
      req = item.requester
      req_list << req.id if req.customer?
      item.save
    end
    
    msg1 = render_to_string(
      :inline => t("helpdesk.flash.flagged_spam", 
                      :tickets => get_updated_ticket_count,
                      :undo => "<%= link_to(t('undo'), { :action => :unspam, :ids => params[:ids] }, { :method => :put }) %>"
                  ))
                    
    link = render_to_string( :inline => "<%= link_to_remote(t('user_block'), :url => block_user_path(:ids => req_list), :method => :put ) %>" ,
      :locals => { :req_list => req_list.uniq } )
      
    notice_msg =  msg1
    notice_msg << " <br />#{t("block_users")} #{link}" unless req_list.blank?
    
    flash[:notice] =  notice_msg 
    respond_to do |format|
      format.html { redirect_to redirect_url  }
      format.js
      format.mobile {  render :json => { :success => true }.to_json }
    end
  end

  def unspam
    @items.each do |item|
      item.spam = false
      item.save
      #mark_requester_deleted(item,false)
    end

    flash[:notice] = render_to_string(
      :inline => t("helpdesk.flash.flagged_unspam", 
                      :tickets => get_updated_ticket_count ))

    respond_to do |format|
      format.html { redirect_to (@items.size == 1) ? helpdesk_ticket_path(@items.first) : :back }
      format.js
    end
  end

  def delete_forever
    ActiveRecord::Base.connection.execute("update helpdesk_schema_less_tickets st inner join helpdesk_tickets t on 
      st.ticket_id= t.id and st.account_id=#{current_account.id} 
      set st.#{Helpdesk::SchemaLessTicket.trashed_column} = 1 where 
      t.id in (#{@items.map(&:id).join(',')}) and t.account_id=#{current_account.id}")    
    Resque.enqueue(Workers::ClearTrash, current_account.id)
    flash[:notice] = render_to_string(
        :inline => t("flash.tickets.delete_forever.success", :tickets => get_updated_ticket_count ))
    redirect_to :back
  end

  def empty_trash
    ActiveRecord::Base.connection.execute("update helpdesk_schema_less_tickets
     st inner join helpdesk_tickets t on st.ticket_id= t.id and st.account_id=#{current_account.id}
       set st.#{Helpdesk::SchemaLessTicket.trashed_column} = 1 
       where t.deleted=1 and t.account_id=#{current_account.id}")
    Resque.enqueue(Workers::ClearTrash, current_account.id)
    flash[:notice] = t(:'flash.tickets.empty_trash.success')
    redirect_to :back
  end

  def empty_spam
    Helpdesk::Ticket.destroy_all(:spam => true)
    flash[:notice] = t(:'flash.tickets.empty_spam.success')
    redirect_to :back
  end
  
  def change_due_by     
    due_date = get_due_by_time    
    @item.update_attributes(:due_by => due_date)
    render :partial => switch_to_new_show? ? "/helpdesk/tickets/show/due_by" : "due_by", :object => @item.due_by
  end  
  
  def get_due_by_time
    due_date_option = params[:due_date_options]
    due_by_time = params[:due_by_date_time] 

    case due_date_option.to_sym()
    when :today
      Time.zone.now.end_of_day
    when :tomorrow
      Time.zone.now.tomorrow.end_of_day
    when :thisweek
      Time.zone.now.end_of_week
    when :nextweek
      Time.zone.now.next_week.end_of_week
    else
      Time.parse(due_by_time).to_s(:db)
    end
  end
  
  def get_ticket_agents
    unless @item.blank?
      @agents = current_account.agents
    end
    render :partial => "get_ticket_agents", :locals => {:ticket_id => @item.display_id}
  end


  def quick_assign
    if allowed_quick_assign_fields.include?(params[:assign])
      unless params[:assign] == 'agent'
        @item.send( params[:assign] + '=' ,  params[:value]) if @item.respond_to?(params[:assign])
      else
        @item.responder = nil
        @item.responder = current_account.users.find(params[:value]) unless params[:value]== "-"
      end
      @item.save
      render :json => {:success => true}.to_json
    else
      render :json => {:success => false}.to_json
    end
  end

  def new
    unless params[:topic_id].nil?
      @topic = Topic.find(params[:topic_id])
      @item.subject     = @topic.title
      @item.description_html = @topic.posts.first.body_html
      @item.requester   = @topic.user
    end
    @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone] #setting for agent new ticket- as phone
    if params['format'] == 'widget'
      render :layout => 'widgets/contacts'
    end
  end
 
  def create
    if !params[:topic_id].blank? 
      @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum]
      @item.build_ticket_topic(:topic_id => params[:topic_id])
    end

    @item.product ||= current_portal.product
    cc_emails = fetch_valid_emails(params[:cc_emails])
    @item.cc_email = {:cc_emails => cc_emails, :fwd_emails => []} 
    @item.status = CLOSED if save_and_close?
    
    build_attachments @item, :helpdesk_ticket

    if @item.save
      post_persist
      notify_cc_people cc_emails unless cc_emails.blank? 
    else
      create_error
    end
  end

  def close 
    status_id = CLOSED
    #@old_timer_count = @item.time_sheets.timer_active.size - will enable this later..not a good solution
    if @item.update_attributes(:status => status_id)
      flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/close_notice')
      redirect_to redirect_url
    else
      flash[:error] = t("helpdesk.flash.closing_the_ticket_failed")
      redirect_to :back
    end
  end
 
  def get_solution_detail   
    sol_desc = current_account.solution_articles.find(params[:id])
    render :text => sol_desc.description || "" 
  end

  def latest_note
    ticket = current_account.tickets.permissible(current_user).find_by_display_id(params[:id])
    if ticket.nil?
      render :text => t("flash.general.access_denied")
    else
      render :partial => "/helpdesk/shared/ticket_overlay", :locals => {:ticket => ticket}
    end
  end

  def save_draft
    set_key(draft_key, params[:draft_data])
    render :nothing => true
  end

  def clear_draft
    remove_key(draft_key)
    render :nothing => true
  end

  def activities
    if params[:since_id].present?
      activity_records = @item.activities.activity_since(params[:since_id])
    elsif params[:before_id].present?
      activity_records = @item.activities.activity_before(params[:before_id])
    else
      activity_records = @item.activities.newest_first.first(3)
    end

    @activities = stacked_activities(activity_records.reverse)
    @total_activities =  @item.activities_count
    if params[:since_id].present? or params[:before_id].present?
      render :partial => "helpdesk/tickets/show/activity.html.erb", :collection => @activities
    else
      render :layout => false
    end
  end

  def status
    render :partial => 'helpdesk/tickets/show/status.html.erb', :locals => {:ticket => @ticket}
  end

  protected
  
    def item_url
      return new_helpdesk_ticket_path if params[:save_and_create]
      return helpdesk_tickets_path if save_and_close?
      @item
    end
  
    def after_destroy_url
      redirect_url
    end
  
    def redirect_url
      helpdesk_tickets_path
    end
    
    def scoper_user_filters
      current_account.ticket_filters.my_ticket_filters(current_user)
    end

    def process_item
       @item.spam = false
       flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/save_and_close_notice') if save_and_close?
    end
    
    def assign_ticket user
      @items.each do |item|
        old_item = item.clone
        item.responder = user
        #item.train(:ham) #Temporarily commented out by Shan
        item.save
      end
    end

    def load_flexifield   
      flexi_arr = Hash.new
      @item.ff_aliases.each do |label|    
        value = @item.get_ff_value(label.to_sym())    
        flexi_arr[label] = value    
        @item.write_attribute label, value
      end  
      @item.custom_field = flexi_arr  
    end

    def update_custom_field  evaluate_on
      flexi_field = evaluate_on.custom_field      
      evaluate_on.custom_field.each do |key,value|    
        flexi_field[key] = evaluate_on.read_attribute(key)      
      end     
      ff_def_id = FlexifieldDef.find_by_account_id(evaluate_on.account_id).id    
      evaluate_on.ff_def = ff_def_id       
      unless flexi_field.nil?     
        evaluate_on.assign_ff_values flexi_field    
      end
    end

    def choose_layout 
      layout_name = request.headers['X-PJAX'] ? 'maincontent' : 'application'
      case action_name
        when "print"
          layout_name = 'print'
      end
      layout_name
    end
    
    def get_updated_ticket_count
      pluralize(@items.length, t('ticket_was'), t('tickets_were'))
  end
  
   def is_num?(str)
    Integer(str)
   rescue ArgumentError
    false
   else
    true
  end

  def load_email_params
    @signature = current_user.agent.signature_value || ""
    @email_config = current_account.primary_email_config
    @reply_email = current_account.features?(:personalized_email_replies) ? current_account.reply_personalize_emails(current_user.name) : current_account.reply_emails
    @ticket ||= current_account.tickets.find_by_display_id(params[:id])
    @selected_reply_email = current_account.features?(:personalized_email_replies) ? @ticket.friendly_reply_email_personalize(current_user.name) : @ticket.selected_reply_email
  end

  def load_conversation_params
    @conv_id = params[:note_id]
    @note = @ticket.notes.visible.find_by_id(@conv_id) unless @conv_id.nil?
  end

  def load_reply_to_all_emails
    @ticket_notes = @ticket.conversation(nil,5,[:survey_remark, :user, :attachments, :schema_less_note])
    reply_to_all_emails
  end

  
  private
  
    def reply_to_all_emails
      if @ticket_notes.blank?
        @to_cc_emails = @ticket.reply_to_all_emails
      else
        cc_email_hash = @ticket.cc_email_hash
        @to_cc_emails = cc_email_hash && cc_email_hash[:cc_emails] ? cc_email_hash[:cc_emails] : []
      end
    end

    def redis_key
      HELPDESK_TICKET_FILTERS % {:account_id => current_account.id, :user_id => current_user.id, :session_id => session.session_id}
    end

    def allowed_quick_assign_fields
      ['agent','status','priority']
    end

    def cache_filter_params
      filter_params = params.clone
      filter_params.delete(:action)
      filter_params.delete(:controller)
      
      set_key(redis_key, filter_params.to_json, 86400)

      @cached_filter_data = get_cached_filters
    end

    def add_requester_filter
      email = params[:email]
      unless email.blank?
        requester = current_account.all_users.find_by_email(email) 
        @user_name = email
        unless requester.nil?
          params[:requester_id] = requester.id;
        else
          @response_errors = {:no_email => true}
        end
      end
      company_name = params[:company_name]
      unless company_name.blank?
        company = current_account.customers.find_by_name(company_name)
        unless(company.nil?)
          params[:company_id] = company.id
        else
          @response_errors = {:no_company => true}
        end
      end
    end

    def get_cached_filters
      filters_str = get_key(redis_key)
      JSON.parse(filters_str) if filters_str
    end

    def load_cached_ticket_filters
      if custom_filter?
        @cached_filter_data = get_cached_filters

        if @cached_filter_data
          @cached_filter_data.symbolize_keys!
          @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
          @ticket_filter = @ticket_filter.deserialize_from_params(@cached_filter_data)
          @ticket_filter.query_hash = JSON.parse(@cached_filter_data[:data_hash]) unless @cached_filter_data[:data_hash].blank?
          params.merge!(@cached_filter_data)
        end
      else 
        remove_key(redis_key)
      end
    end

    def custom_filter?
      params[:filter_key].blank? and params[:filter_name].blank? and params[:requester_id].blank?
    end

    def load_ticket_filter
      return if @cached_filter_data

      filter_name = @template.current_filter
      if !is_num?(filter_name)
        load_default_filter(filter_name)
      else
        @ticket_filter = current_account.ticket_filters.find_by_id(filter_name)
        return load_default_filter(TicketsFilter::DEFAULT_FILTER) if @ticket_filter.nil? or !@ticket_filter.has_permission?(current_user)
        @ticket_filter.query_hash = @ticket_filter.data[:data_hash]

        params.merge!(@ticket_filter.attributes["data"])
      end
    end

    def load_default_filter(filter_name)
      params[:filter_name] = filter_name
      @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME)
      @ticket_filter.query_hash = @ticket_filter.default_filter(filter_name)
      @ticket_filter.accessible = current_account.user_accesses.new
      @ticket_filter.accessible.visibility = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
    end

    def check_user
      if !current_user.nil? and current_user.customer?
        return redirect_to support_ticket_url(@ticket,:format => params[:format])
      end
    end

    def verify_permission
      unless current_user && current_user.has_ticket_permission?(@item) && !@item.trashed
        flash[:notice] = t("flash.general.access_denied") 
        if params['format'] == "widget"
          return false
        else
          redirect_to helpdesk_tickets_url
        end
      end
      true
    end
 
  def save_and_close?
    !params[:save_and_close].blank?
  end

  def notification_not_required?
    (!params[:save_and_close].blank?) || (params[:disable_notification] && params[:disable_notification].to_bool) || 
    (params[:action] == "quick_assign" && params[:assign] == "status" && params[:disable_notification] && params[:disable_notification].to_bool)
  end

  def check_ticket_status
    if params["helpdesk_ticket"]["status"].blank?
      flash[:error] = t("change_deleted_status_msg")
      redirect_to item_url
    end
  end

  def set_default_filter
    params[:filter_name] = "all_tickets" if params[:filter_name].blank? && params[:filter_key].blank? && params[:data_hash].blank?
    # When there is no data hash sent selecting all_tickets instead of new_my_open
  end

  def draft_key
    HELPDESK_REPLY_DRAFTS % { :account_id => current_account.id, :user_id => current_user.id, 
      :ticket_id => @ticket.id}
  end

  def update_tags
    new_tag_list= params[:helpdesk][:tags].split(",").map { |tag| tag.strip}
    old_tag_list = @item.tags.map{|tag| tag.name}

    add_ticket_tags( new_tag_list.select {|tag| !old_tag_list.include?(tag) })
    #Choosing the ones that are not in the old list.

    remove_ticket_tags(old_tag_list.select {|tag| !new_tag_list.include?(tag) }) 
    #Choosing the ones that are in the old list and not in the new ones.

  end

  def add_ticket_tags(tags_to_be_added)

    begin
      tags_to_be_added.each do |tag_string|
        tag = Helpdesk::Tag.find_by_name_and_account_id(tag_string, current_account) || Helpdesk::Tag.new(:name => tag_string, :account_id => current_account.id)
        @item.tags << tag
      end
    rescue ActiveRecord::RecordInvalid => e
    end

  end

  def remove_ticket_tags(tags_to_be_removed)

    tags = current_account.tags.find_all_by_name(tags_to_be_removed)  
    unless tags.blank?

      # Helpdesk::TagUse.find_all_by_taggable_id_and_tag_id_and_taggable_type().destroy is not working - Hence trying a different route.
      tag_uses = Helpdesk::TagUse.find_all_by_taggable_id_and_tag_id_and_taggable_type(@item.id, tags.map{ |tag| tag.id } ,"Helpdesk::Ticket" ).collect(&:id)
      Helpdesk::TagUse.destroy tag_uses

      #Decrementing Tag Uses Count (on multiple items)
      # Helpdesk::Tag.update_all("tag_uses_count = tag_uses_count -1", {:id => tags.collect(&:id)})

    end

  end

  def set_show_version
    @new_show_page = cookies[:new_details_view].present? && cookies[:new_details_view].eql?("true")
  end

  def set_selected_tab
    @selected_tab = :tickets
  end

  def load_installed_apps
    @installed_apps_hash = current_account.installed_apps_hash
  end
end
