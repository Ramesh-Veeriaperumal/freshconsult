class Helpdesk::TicketsController < ApplicationController  

  before_filter :check_user , :only => [:show]
  
  before_filter { |c| c.requires_permission :manage_tickets }

  include HelpdeskControllerMethods
  
  before_filter :get_custom_fields,   :only => [:create ,:update]
  before_filter :load_multiple_items, :only => [:destroy, :restore, :spam, :unspam, :assign , :close_multiple ,:pick_tickets]  
  before_filter :load_item,     :only => [:show, :edit, :update, :execute_scenario, :close_ticket ] 
  before_filter :load_flexifield , :only =>[:execute_scenario]
  before_filter :set_customizer , :only => [:new ,:edit ,:show]
  before_filter :set_custom_fields , :only => [:create ,:update]
  
  
  def check_user
    if !current_user.nil? and current_user.customer?
      return redirect_to(support_ticket_url(@ticket))
    end
  end
  
  
 
  def index
 
    @items = TicketsFilter.filter(@template.current_filter, current_user, current_account.tickets)

    @items = TicketsFilter.search(@items, params[:f], params[:v])

    respond_to do |format|
      format.html  do
        @items = @items.paginate(
          :page => params[:page], 
          :order => TicketsFilter::SORT_SQL_BY_KEY[(params[:sort] || :due_by).to_sym ] +" #{params[:sort_order]}"  ,
          :per_page => 10)
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
     @signature = "\n\n\n #{@agents.signature}" unless (@agents.nil? || @agents.signature.blank?)
     
     logger.debug "subject of the ticket is #{@item.subject}"
     
     set_suggested_solutions 
    
    respond_to do |format|
      format.html  
      format.atom
    end
  end

  def set_suggested_solutions
   @articles = Solution::Article.suggest_solutions @ticket   
   #@articles =[]
  end
  
  def update

    old_item = @item.clone
    if @item.update_attributes(params[nscname])

      if old_item.responder_id != @item.responder_id
        unless @item.responder
          @item.create_activity(current_user, "{{user_path}} assgned the ticket {{notable_path}} to 'Nobody'", {}, 
                                   "Assigned to 'Nobody' by {{user_path}}")
        else
          @item.create_activity(current_user, 
                  "{{user_path}} #{old_item.responder ? "reassigned" : "assigned"} the ticket {{notable_path}} to {{responder_path}}", 
                  {'eval_args' => {'responder_path' => ['responder_path', {
                                                          'id' => @item.responder.id, 
                                                          'name' => @item.responder.name}]}}, 
                  "Assigned to {{responder_path}} by {{user_path}}")
        end
      end

      if old_item.status != @item.status
        @item.create_activity(current_user,
                "{{user_path}} changed the ticket status of {{notable_path}} to {{status_name}}",
                {'status_name' => @item.status_name}, 
                "{{user_path}} changed the status to {{status_name}}")
      end
      
      if old_item.priority != @item.priority
        @item.create_activity(current_user,
                "{{user_path}} changed the ticket priority of {{notable_path}} to {{priority_name}}",
                {'priority_name' => @item.priority_name}, 
                "{{user_path}} changed the priority to {{priority_name}}")
      end

      flash[:notice] = "The #{cname.humanize.downcase} has been updated"
      redirect_to item_url
    else
      edit_error
    end
  end

  def assign
    user = params[:responder_id] ? User.find(params[:responder_id]) : current_user
    
    assign_ticket user

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
    @item.create_activity(current_user, "{{user_path}} executed the scenario '{{scenario_name}}' on {{notable_path}}", 
                            { 'scenario_name' => va_rule.name },
                            "{{user_path}} executed the scenario '{{scenario_name}}'")
    
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
    flash[:notice] = "All tickets in the trash folder were deleted."
    redirect_to :back
  end

  def empty_spam
    Helpdesk::Ticket.destroy_all(:spam => true)
    flash[:notice] = "All tickets in the spam folder were deleted."
    redirect_to :back
  end

  def get_agents
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
      @item.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum]
      @item.requester = @topic.user
    end
  end
 
  def create
   if params[:topic_id].length > 0 
        @item.build_ticket_topic(:topic_id => params[:topic_id])
   end
    if @item.save!  
      post_persist
    else
      create_error
    end
  end
 
   def close_ticket 
     status_id = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:closed]
     logger.debug "close the ticket...with status id  #{status_id}"
     res = Hash.new
     if @item.update_attribute(:status , status_id)
       res["success"] = true
       res["status"] = 'Closed'
       res["value"] = status_id
       res["message"]="Successfully updated"
       render :json => ActiveSupport::JSON.encode(res)
     else
       res["success"] = false
       res["message"]="closing the ticket failed"
       render :json => ActiveSupport::JSON.encode(res)
       
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

  def process_item
    
    #handle_custom_fields
    #if @item.source == 0
      @item.spam = false
      @item.create_activity(current_user, "{{user_path}} created a new ticket {{notable_path}}", {},
                            "{{user_path}} created the ticket")
    #end
   
 end
 
 def assign_ticket user
   
    @items.each do |item|
      old_item = item.clone
      message = "#{item.responder ? "Reassigned" : "Assigned"} to #{user.name}"
      item.responder = user
      item.train(:ham)
      item.save
      if old_item.responder_id != item.responder_id
        unless item.responder
          item.create_activity(current_user, "{{user_path}} assgned the ticket {{notable_path}} to 'Nobody'", {}, 
                                   "Assigned to 'Nobody' by {{user_path}}")
        else
          item.create_activity(current_user, "{{user_path}} #{old_item.responder ? "reassigned" : "assigned"} the ticket {{notable_path}} to {{responder_path}}", 
                  {'eval_args' => {'responder_path' => ['responder_path', {
                                                          'id' => item.responder.id, 
                                                          'name' => item.responder.name}]}}, 
                  "Assigned to {{responder_path}} by {{user_path}}")
        end
      end
      #item.create_status_note(current_account, message, current_user, "#{item.responder ? "reassigned" : "assigned"} the ticket")
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
