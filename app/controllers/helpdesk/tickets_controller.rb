require 'fastercsv'

class Helpdesk::TicketsController < ApplicationController  
  
  include ActionView::Helpers::TextHelper
  
  before_filter :check_user , :only => [:show]
  before_filter :load_ticket_filter , :only => [:index, :custom_view_save]
  before_filter { |c| c.requires_permission :manage_tickets }
  
  include HelpdeskControllerMethods  
  include Helpdesk::TicketActions
  include Search::TicketSearch
  
  layout :choose_layout 
  
  before_filter :load_multiple_items, :only => [:destroy, :restore, :spam, :unspam, :assign , :close_multiple ,:pick_tickets]  
  before_filter :load_item,           :only => [:show, :edit, :update, :execute_scenario, :close, :change_due_by, :get_ca_response_content, :print] 
  before_filter :load_flexifield ,    :only => [:execute_scenario]
  before_filter :set_date_filter ,    :only => [:export_csv]

  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR
  
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
      return redirect_to(support_ticket_url(@ticket))
    end
  end
  
  def user_ticket
    @user = current_account.users.find_by_email(params[:email])
    if !@user.nil?
      @tickets =  Helpdesk::Ticket.requester_active(@user)
    else
      @tickets = []
    end
    respond_to do |format|
      format.xml do
        render :xml => @tickets.to_xml
      end
    end
  end
 
  def index
    @items = current_account.tickets.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter') 
    @filters_options = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
    @current_options = @ticket_filter.query_hash.map{|i|{ i["condition"] => i["value"] }}.inject({}){|h, e|h.merge! e}
    @show_options = show_options
    @current_view = @ticket_filter.id || @ticket_filter.name
    @is_default_filter = (!is_num?(@template.current_filter))
        
    respond_to do |format|      
      format.html  do
      end      
      format.xml do
        render :xml => @items.to_xml
      end      
      format.json do
        render :json => Hash.from_xml(@items.to_xml)
      end      
      format.atom do
      end
    end
  end
  
  def custom_view_save
     render :partial => "helpdesk/tickets/customview/new"
  end
  
  def custom_search
    @items = current_account.tickets.filter(:params => params, :filter => 'Helpdesk::Filters::CustomTicketFilter')
    render :partial => "custom_search"
  end
  
  def show
    @reply_email = current_account.reply_emails
    @subscription = current_user && @item.subscriptions.find(
      :first, 
      :conditions => {:user_id => current_user.id})
      
    @signature = ""
    @agents = Agent.find(:first, :joins=>:user, :conditions =>{:user_id => current_user.id} )     
    @signature = RedCloth.new("#{@agents.signature}").to_html unless (@agents.nil? || @agents.signature.blank?)
     
    @ticket_notes = @ticket.conversation
    
    respond_to do |format|
      format.html  
      format.atom
      format.xml  { 
        render :xml => @item.to_xml  
      }
      format.json {
        render :json => Hash.from_xml(@item.to_xml)
      }
      format.js
    end
  end
  
  def update
    old_item = @item.clone
    if @item.update_attributes(params[nscname])
      flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
      redirect_to item_url
    else
      edit_error
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
  
  def close_multiple
    status_id = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:closed]       
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

    flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/execute_scenario_notice', 
                                      :locals => { :actions_executed => Va::Action.activities, :rule_name => va_rule.name })

    respond_to do |format|
      format.html { redirect_to :back }
      format.js
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
    @agents = current_account.agents.all(:include =>:user)
    @agents = AgentGroup.find(:all, :joins=>:user, :conditions => { :group_id =>group_id ,:users =>{:account_id =>current_account.id} } ) unless group_id.nil?
    render :partial => "agent_groups"
  end
  
  def new
    unless params[:topic_id].nil?
      @topic = Topic.find(params[:topic_id])
      @item.subject     = @topic.title
      @item.description = @topic.posts.first.body
      @item.requester   = @topic.user
    end
  end
 
  def create
    if !params[:topic_id].blank? 
      @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum]
      @item.build_ticket_topic(:topic_id => params[:topic_id])
    end
    
    if @item.save
      post_persist
    else
      create_error
    end
  end

  def close 
    status_id = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:closed]
    logger.debug "Closed the ticket with status id #{status_id}"
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
    a_template = Liquid::Template.parse(ca_resp.content_html).render('ticket' => @item, 'helpdesk_name' => @item.account.portal_name)    
    render :text => a_template || ""
  end 
    
  protected
  
    def item_url
      return new_helpdesk_ticket_path if params[:save_and_create]
      @item
    end
  
    def after_destroy_url
      redirect_url
    end
  
    def redirect_url
      { :action => 'index' }
    end
    
    def scoper_user_filters
      current_account.ticket_filters.my_ticket_filters(current_user)
    end

    def process_item
      #if @item.source == 0
        @item.spam = false
#        @item.create_activity(@item.requester, 'activities.tickets.new_ticket.long', {},
#                              'activities.tickets.new_ticket.short')
#      #end
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

end
