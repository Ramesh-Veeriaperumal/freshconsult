class Helpdesk::TimeSheetsController < ApplicationController
  
  before_filter { |c| c.requires_feature :timesheets }
  before_filter { |c| c.requires_permission :manage_tickets }  
  before_filter :set_show_version
  before_filter :load_time_entry, :only => [ :show,:edit, :update, :destroy, :toggle_timer ] 
  before_filter :load_ticket, :only => [:create, :index, :edit, :new, :update, :toggle_timer] 
  before_filter :load_installed_apps, :only => [:index, :create, :new, :edit, :update, :toggle_timer, :destroy]

  rescue_from ActiveRecord::UnknownAttributeError , :with => :handle_error

  def index
    unless @ticket.nil?
      @time_sheets = @ticket.time_sheets  unless @ticket.nil?
    else
      get_time_sheets #Added for time_sheets API
    end
    respond_to do |format|
      format.html do 
        render :index, :layout => false
      end
      format.xml do
        render :xml=>@time_sheets.to_xml({:root=>"time_entries"})
      end
       format.json do
        render :json=>@time_sheets.to_json()
      end
    end
  end

  def new
    render :layout => false
  end
  
  def create
    hours_spent = params[:time_entry][:hours]
    params[:time_entry].delete(:hours)

    update_running_timer params[:time_entry][:user_id] if hours_spent.blank?
    
    #Added for API calls where user will not be knowing the id for ticket, instead provide only the display id.
    if params[:time_entry][:ticket_id].blank? #this will be always present when called from portal's 'Add Time'
      check_ticket = current_account.tickets.find_by_display_id(params[:ticket_id]) unless params[:ticket_id].nil?
      unless check_ticket.blank?
        params[:time_entry][:ticket_id] = check_ticket.id
      else
          raise ActiveRecord::RecordNotFound
      end
    end

    time_entry = params[:time_entry].merge!({:start_time => Time.zone.now(),
                                             :executed_at => Time.zone.now(),
                                             :time_spent => get_time_in_second(hours_spent),
                                             :timer_running => hours_spent.blank?,
                                             :billable => true})

    @time_entry = scoper.new(time_entry)    #throws unknown attribute error
    if @time_entry.save!
      respond_to_format @time_entry
    end
  end
   
  def show
     respond_to_format @time_entry
  end

  def update  
    hours_spent = params[:time_entry][:hours]
    params[:time_entry].delete(:hours)
    time_entry = params[:time_entry].merge!({:time_spent => get_time_in_second(hours_spent)})

    if @time_entry.update_attributes(time_entry)
      respond_to_format @time_entry
    end
  end 
  
  def toggle_timer     
     if @time_entry.timer_running
        @time_entry.update_attributes({ :timer_running => false, :time_spent => calculate_time_spent(@time_entry) })        
     else
        update_running_timer @time_entry.user_id
        @time_entry.update_attributes({ :timer_running => true, :start_time => Time.zone.now })
     end
     respond_to_format @time_entry
  end
  
  def time_sheets_for_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:id])
    @time_sheets = @ticket.time_sheets.group_by(&:group_by_day_criteria) || []
    render :partial => "helpdesk/time_sheets/time_sheets_for_ticket"
  end
  
  def time_sheets_by_agents
     @ticket = current_account.tickets.find_by_display_id(params[:id])
     @items = @ticket.time_sheets.group_by(&:user) || [] 
     #need to render a new partial- u may iterate as--@items.each{|key,val| val.each{|t| puts t.note}}
  end

  def destroy
    @time_entry.destroy
    respond_to_format @time_entry
  end

private
  def scoper
    current_account.time_sheets
  end
 
  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end 
     
  def get_time_in_second time_hour
    s = time_hour.to_f * 60 * 60 
  end
  
  def load_time_entry
    @time_entry = scoper.find(params[:id])
  end
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end
  
  def total_time_spent time_sheets
    total_time_in_sec = time_sheets.collect{|t| t.time_spent}.sum
    hours = total_time_in_sec.div(60*60)
    minutes_as_percent = (total_time_in_sec.div(60) % 60)*(1.667).round
    total_time = hours.to_s()+"."+ minutes_as_percent.to_s()
    total_time
  end
  
  #Following method will stop running timer for the user. at a time one user can have only one timer..
  def update_running_timer user_id
    @time_cleared = current_account.time_sheets.find_by_user_id_and_timer_running(user_id, true)
    if @time_cleared
       @time_cleared.update_attributes({:timer_running => false, :time_spent => calculate_time_spent(@time_cleared) }) 
    end
  end
  
  def calculate_time_spent time_entry
    from_time = time_entry.start_time
    to_time = Time.zone.now
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    running_time =  ((to_time - from_time).abs).round 
    return (time_entry.time_spent + running_time)
  end

  def set_show_version
    @new_show_page = cookies[:new_details_view].present? && cookies[:new_details_view].eql?("true")
  end
  
  def respond_to_format result
    respond_to do |format|
      format.js
      format.html
      format.xml do 
        render :xml => result.to_xml and return 
      end
      format.json do
        render :json => result.to_json and return 
      end
    end
  end

  #API Method
  def get_time_sheets
    # start date is set to the zero if nothing is specified similarly End date is set to current time.
    start_date = (params[:start_date].blank?) ? 0: params[:start_date] 
    end_date =  (params[:end_date].blank?) ? Time.zone.now.to_time : params[:end_date]
    
    #agent/email name 
    email = params[:email]
    unless email.blank?
      requester = current_account.all_users.find_by_email(email) 
      unless requester.nil? 
        params[:agent_id] = requester.agent.user_id if requester.agent?
        Rails.logger.debug "Timesheets API::get_time_sheets:  params[:email] is a agent =>" + (requester.agent?).to_s
      end
    end
    customer_id = params[:customer_id] || [] 
    unless params[:customer_name].blank?
      customer = current_account.customers.find_by_name(params[:customer_name])
      # raise ActiveRecord::RecordNotFound if(customer.blank?)#indication customer not found
      customer_id = customer.id unless customer.nil?
    end
    agent_id = params[:agent_id] || []

    billable = (!params[:billable].blank? && !params[:billable].to_s.eql?("falsetrue")) ? [params[:billable].to_s.to_bool] : true
    #search by contact
    contact_email = params[:contact_email]

    #customer_id and agent_id if passed null will return all data.  
    unless contact_email.blank?
      Rails.logger.debug "Timesheets API::get_time_sheets: contact_email=> "+contact_email +" agent_id =>"+ agent_id.to_s() + " billable=>" + billable.to_s+ " from =>"+ start_date.to_s+ " till=> " + end_date.to_s
      @time_sheets = current_account.time_sheets.for_contacts(contact_email).by_agent(agent_id).created_at_inside(start_date,end_date).hour_billable(billable)
    else
      Rails.logger.debug "Timesheets API::get_time_sheets: customer_id=> "+customer_id.to_s() +" agent_id =>"+ agent_id.to_s() + " billable=>" + billable.to_s+ " from =>"+ start_date.to_s+ " till=> " + end_date.to_s
      @time_sheets = current_account.time_sheets.for_customers(customer_id).by_agent(agent_id).created_at_inside(start_date,end_date).hour_billable(billable)
    end

  end

  def load_installed_apps
    @installed_apps_hash = current_account.installed_apps_hash
  end

end

