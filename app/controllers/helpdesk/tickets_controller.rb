class Helpdesk::TicketsController < ApplicationController  

  before_filter :check_user , :only => [:show]
  before_filter { |c| c.requires_permission :manage_tickets }

  include HelpdeskControllerMethods
  
  before_filter :load_multiple_items, :only => [:destroy, :restore, :spam, :unspam, :assign , :close_multiple ,:pick_tickets]  
  before_filter :load_item,     :only => [:show, :edit, :update, :execute_scenario, :close ,:change_due_by] 
  before_filter :load_flexifield , :only =>[:execute_scenario]
  before_filter :set_customizer , :only => [:new ,:edit ,:show]
  
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
    @items = TicketsFilter.filter(@template.current_filter, current_user, current_account.tickets)
    @items = TicketsFilter.search(@items, params[:f], params[:v])
    respond_to do |format|
      format.html  do
        @items = @items.paginate(
          :page => params[:page], 
          :order => @template.cookie_sort,
          :per_page => 10)
      end
      
      format.xml do
        render :xml => @items.to_xml
      end
      
      format.json do
        render :json => Hash.from_xml(@items.to_xml)
      end
      
      format.atom do
        @items = @items.newest(20)
      end
    end
  end

  def show
    @reply_email = current_account.reply_emails
    @subscription = current_user && @item.subscriptions.find(
      :first, 
      :conditions => {:user_id => current_user.id})
      
    @signature = ""
    @agents = Agent.find(:first, :joins=>:user, :conditions =>{:user_id =>current_user.id} )     
    @signature = "\n\n\n#{@agents.signature}" unless (@agents.nil? || @agents.signature.blank?)
     
    @ticket_notes = @ticket.notes.visible.exclude_source('meta').newest_first
    set_suggested_solutions 
    
    respond_to do |format|
      format.html  
      format.atom
      format.xml  { 
      render :xml => @item.to_xml  
      }
      format.json {
      render :json => Hash.from_xml(@item.to_xml)
      }
    end
  end
  
  def set_suggested_solutions
    @articles = Solution::Article.suggest_solutions @ticket   
  end
  
  def update
    old_item = @item.clone
    if @item.update_attributes(params[nscname])
      create_assigned_activity(old_item, @item) if old_item.responder_id != @item.responder_id
      
      if old_item.status != @item.status
        @item.create_activity(current_user, 'activities.tickets.status_change.long',
          {'status_name' => @item.status_name}, 'activities.tickets.status_change.short')
      end
      
      if old_item.priority != @item.priority
        @item.create_activity(current_user, 'activities.tickets.priority_change.long',
          {'priority_name' => @item.priority_name}, 'activities.tickets.priority_change.short')
      end

      flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
      redirect_to item_url
    else
      edit_error
    end
  end

  def assign
    user = params[:responder_id] ? User.find(params[:responder_id]) : current_user #Need to use scoping..
    assign_ticket user

    #by Shan to do i18n
    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> assigned to #{user.name}.")

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
    
    flash[:notice] = render_to_string(:inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> closed")  
    redirect_to :back
  end
 
  def pick_tickets
    assign_ticket current_user
    flash[:notice] = render_to_string(:inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> assigned to you")  
    redirect_to :back
  end
  
  def execute_scenario 
    va_rule = current_account.scn_automations.find(params[:scenario_id])    
    va_rule.trigger_actions(@item)
    update_custom_field @item    
    @item.save
    @item.create_activity(current_user, 'activities.tickets.execute_scenario.long', 
      { 'scenario_name' => va_rule.name }, 'activities.tickets.execute_scenario.short')
    
    actions_executed = Va::Action.activities.collect { |a| "<li>#{a}</li>" }
    Va::Action.clear_activities #by Shan
    
    flash[:notice] = render_to_string(:inline => "Executed the scenario <b>'#{va_rule.name}'</b> <a href='#' class='show-list'>view details</a> 
                                                <div class='list'> <h4 class='title'>Actions performed</h4> <ul> #{actions_executed.join} </ul> </div>")
                                  
    redirect_to :back
  end 

  def spam
    @items.each do |item|
      item.train(:spam)
      item.save
    end

    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> flagged as spam. <%= link_to('Undo', { :action => :unspam, :ids => params[:ids] }, { :method => :put }) %>")

    redirect_to :back
  end

  def unspam
    @items.each do |item|
      item.train(:ham)
      item.save
    end

    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> removed from the spam folder.")

    redirect_to :back
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
    @agents = AgentGroup.find(:all, :joins=>:user, :conditions =>{:group_id =>group_id ,:users =>{:account_id =>current_account.id} } ) unless group_id.nil?
    render :partial => "agent_groups"
  end
  
  def new
    unless params[:topic_id].nil?
      @topic = Topic.find(params[:topic_id])
      @item.subject = @topic.title
      @item.description = @topic.posts.first.body
      @item.requester = @topic.user
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
    logger.debug "close the ticket...with status id  #{status_id}"
    if @item.update_attribute(:status , status_id)
      flash[:notice] = render_to_string(:partial => '/helpdesk/tickets/close_notice')
      redirect_to redirect_url
    else
      flash[:error] = "Closing the ticket failed"
      redirect_to :back
    end
  end
 
  def get_solution_detail   
    sol_desc = current_account.solution_articles.find(params[:id])
    render :text => (sol_desc.description.gsub(/<\/?[^>]*>/, "")).gsub(/&nbsp;/i,"") || "" 
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

    def process_item
      #if @item.source == 0
        @item.spam = false
        @item.create_activity(@item.requester, 'activities.tickets.new_ticket.long', {},
                              'activities.tickets.new_ticket.short')
      #end
    end
 
    def assign_ticket user
      @items.each do |item|
        old_item = item.clone
        message = "#{item.responder ? "Reassigned" : "Assigned"} to #{user.name}"
        item.responder = user
        #item.train(:ham) #Temporarily commented out by Shan
        item.save
        create_assigned_activity(old_item, item) if old_item.responder_id != item.responder_id
      end
    end
  
    def create_assigned_activity(old_item, item)
      unless item.responder
        item.create_activity(current_user, 'activities.tickets.assigned_to_nobody.long', {}, 
                                 'activities.tickets.assigned_to_nobody.short')
      else
        item.create_activity(current_user, 
          old_item.responder ? 'activities.tickets.reassigned.long' : 'activities.tickets.assigned.long', 
          {'eval_args' => {'responder_path' => ['responder_path', 
            {'id' => item.responder.id, 'name' => item.responder.name}]}}, 
          'activities.tickets.assigned.short')
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

end
