require 'fastercsv'
require 'html2textile'

class Helpdesk::TicketsController < ApplicationController  
  
  include ActionView::Helpers::TextHelper
  include ParserUtil

  before_filter :check_user , :only => [:show]
  before_filter :load_ticket_filter , :only => [:index, :show, :custom_view_save, :latest_ticket_count]
  before_filter :add_requester_filter , :only => [:index, :user_tickets]
  before_filter :disable_notification, :if => :save_and_close?
  after_filter  :enable_notification, :if => :save_and_close?

  before_filter :set_mobile, :only => [:index, :show,:update, :create, :get_ca_response_content, :execute_scenario, :assign, :spam, :get_agents ]
  
  before_filter { |c| c.requires_permission :manage_tickets }
  
  include HelpdeskControllerMethods  
  include Helpdesk::TicketActions
  include Search::TicketSearch
  include Helpdesk::Ticketfields::TicketStatus
  
  layout :choose_layout 
  
  before_filter :load_multiple_items, :only => [:destroy, :restore, :spam, :unspam, :assign , :close_multiple ,:pick_tickets, :update_multiple]  
  before_filter :load_item, :verify_permission  ,   :only => [:show, :edit, :update, :execute_scenario, :close, :change_due_by, :get_ca_response_content, :print] 
  before_filter :load_flexifield ,    :only => [:execute_scenario]
  before_filter :set_date_filter ,    :only => [:export_csv]
  #before_filter :set_latest_updated_at , :only => [:index, :custom_search]
  before_filter :check_ticket_status, :only => [:update]
  before_filter :serialize_params_for_tags , :only => [:index, :custom_search, :export_csv]

  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR
  
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

  def load_ticket_filter
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
  
  def user_ticket
    @user = current_account.users.find_by_email(params[:email])
    if !@user.nil?
      @tickets =  current_account.tickets.visible.requester_active(@user)
    else
      @tickets = []
    end
    respond_to do |format|
      format.xml do
        render :xml => @tickets.to_xml
      end
    end
  end
  
  def set_latest_updated_at
     @latest_updated_at = current_account.tickets.maximum(:updated_at).to_formatted_s(:db)   
  end
 
  def index
    @items = current_account.tickets.permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter') 

    if @items.empty? && !params[:page].nil? && params[:page] != '1'
      params[:page] = '1'  
      @items = current_account.tickets.permissible(current_user).filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter') 
    end

    respond_to do |format|      
      format.html  do
        @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
        @current_options = @ticket_filter.query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
        @show_options = show_options
        @current_view = @ticket_filter.id || @ticket_filter.name
        @is_default_filter = (!is_num?(@template.current_filter))
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
  
  def set_prev_next_tickets
    if params[:filters].nil?
      @filters = {}
      
      if @item.deleted?
        @filters = {:filter_name => "deleted"}
      elsif @item.spam?
        @filters = {:filter_name => "spam"}
      else
        @filters = {:filter_name => "all_tickets"}
      end
      conditions = @item.get_default_filter_permissible_conditions(current_user)     
      @filters.merge!(:data_hash => conditions) unless conditions.blank?
      index_filter = @ticket_filter.deserialize_from_params(@filters)
    else  
      @filters = params[:filters]
      index_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).deserialize_from_params(@filters)
    end

    ticket_ids = index_filter.adjacent_tickets(@ticket, current_account, current_user)
        
    ticket_ids.each do |t|
       (t[2] == "previous") ? @previous_ticket_id = t[1] : @next_ticket_id = t[1]        
    end
    RAILS_DEFAULT_LOGGER.debug "next_previous_tickets : #{@previous_ticket_id} , #{@next_ticket_id}"
  end
  
  def reply_to_all_emails
    if @ticket_notes.blank?
      @to_cc_emails = @ticket.reply_to_all_emails
    else
      cc_email_hash = @ticket.cc_email_hash
      @to_cc_emails = cc_email_hash && cc_email_hash[:cc_emails] ? cc_email_hash[:cc_emails] : []
    end
  end

  def show
    @reply_email = current_account.features?(:personalized_email_replies) ? current_account.reply_personalize_emails(current_user.name) : current_account.reply_emails

    @to_emails = @ticket.to_emails

    @subscription = current_user && @item.subscriptions.find(
      :first, 
      :conditions => {:user_id => current_user.id})
      
    @signature = ""
    @agents = Agent.find(:first, :joins=>:user, :conditions =>{:user_id => current_user.id} )     
    @signature = RedCloth.new("#{@agents.signature}").to_html unless (@agents.nil? || @agents.signature.blank?)
     
    @ticket_notes = @ticket.conversation
    
    @email_config = current_account.primary_email_config

    reply_to_all_emails
    
    respond_to do |format|
      format.html  
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
  
  def update
    old_item = @item.clone
    #old_timer_count = @item.time_sheets.timer_active.size -  we will enable this later
    if @item.update_attributes(params[nscname])
      #flash[:notice] = flash[:notice].chomp(".")+"& \n"+ t(:'flash.tickets.timesheet.timer_stopped') if ((old_timer_count - @item.time_sheets.timer_active.size) > 0)
      respond_to do |format|
        format.html { 
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to item_url 
        }
        format.mobile { 
          render :json => { :success => true, :item => @item }.to_json 
        }
      end
    else
      respond_to do |format|
        format.html { edit_error }
        format.mobile { 
          render :json => { :failure => true, :errors => edit_error }.to_json 
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

    if user === current_user && @items.size == 1
      redirect_to helpdesk_ticket_path(@items.first)
    else
      redirect_to :back
    end
  end
  
  def update_multiple
    params[nscname][:custom_field].delete_if {|key,value| value.blank? } unless params[nscname][:custom_field].nil?
    @items.each do |item|
      params[nscname].each do |key, value|
        if(!value.blank?)
            item.send("#{key}=", value) if item.respond_to?("#{key}=")
        end    
      end
      item.save!
    end
    flash[:notice] = render_to_string(:inline => t("helpdesk.flash.tickets_update", :tickets => get_updated_ticket_count ))
    redirect_to helpdesk_tickets_path
  end
  
  def close_multiple
    status_id = CLOSED       
    @items.each do |item|
      item.update_attribute(:status , status_id)
    end
    
    flash[:notice] = render_to_string(
        :inline => t("helpdesk.flash.tickets_closed", :tickets => get_updated_ticket_count ))
    redirect_to :back
  end
 
  def pick_tickets
    assign_ticket current_user
    flash[:notice] = render_to_string(
        :inline => t("helpdesk.flash.assigned_to_you", :tickets => get_updated_ticket_count ))
    redirect_to :back
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
      format.js
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

  def empty_trash
    Helpdesk::Ticket.destroy_all(:deleted => true)
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
    @item.update_attribute(:due_by , due_date)
    render :partial => "due_by", :object => @item.due_by
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
  
  def get_agents #This doesn't belong here.. by Shan
    group_id = params[:id]
    blank_value = !params[:blank_value].blank? ? params[:blank_value] : "..."
    @agents = current_account.agents.all(:include =>:user)
    @agents = AgentGroup.find(:all, :joins=>:user, :conditions => { :group_id =>group_id ,:users =>{:account_id =>current_account.id} } ) unless group_id.nil?
    respond_to do |format|
      format.html {
        render :partial => "agent_groups", :locals =>{ :blank_value => blank_value }
      }
      format.mobile {
        json = "["; sep=""
          @agents.each { |agent_group|
            user = agent_group.user
            #Removing the root node, so that it conforms to JSON REST API standards
            # 8..-2 will remove "{user:" and the last "}"
            json << sep + user.to_mob_json()[8..-2]; sep=","
          }
        render :json => json + "]"
      }
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
    cc_emails = validate_emails(params[:cc_emails])
    @item.cc_email = {:cc_emails => cc_emails || [], :fwd_emails => []} 

    @item.status = CLOSED if save_and_close?
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
    if @item.update_attribute(:status , status_id)
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

  def get_ca_response_content   
    ca_resp = current_account.canned_responses.find(params[:ca_resp_id])
    content = ca_resp.content_html
    if mobile?
      parser = HTMLToTextileParser.new
      parser.feed ca_resp.content_html
      content = parser.to_textile
    end
    a_template = Liquid::Template.parse(content).render('ticket' => @item, 'helpdesk_name' => @item.account.portal_name)    
    render :text => a_template || ""
  end 
  
  def latest_note
    ticket = current_account.tickets.permissible(current_user).find_by_display_id(params[:id])
    if ticket.nil?
      render :text => t("flash.general.access_denied")
    else
      render :partial => "/helpdesk/shared/ticket_overlay", :locals => {:ticket => ticket}
    end
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
      helpdesk_tickets_path(:page => params[:page])
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
      layout_name = 'application'
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
  
  private
  
   def verify_permission
      unless current_user && current_user.has_ticket_permission?(@item)
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

  def check_ticket_status
    if params["helpdesk_ticket"]["status"].blank?
      flash[:error] = t("change_deleted_status_msg")
      redirect_to item_url
    end
  end

end
