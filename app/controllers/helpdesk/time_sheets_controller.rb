# encoding: utf-8
class Helpdesk::TimeSheetsController < ApplicationController

  include CustomerDeprecationMethods::NormalizeParams
  include Helpdesk::Permissions

  before_filter { |c| c.requires_feature :timesheets }
  before_filter :load_time_entry, :only => [ :show,:edit, :update, :destroy, :toggle_timer ] 
  before_filter :load_ticket, :only => [:new, :create, :index, :edit, :update, :toggle_timer] 
  before_filter :create_permission, :only => :create 
  before_filter :validate_params, :only => [:create, :update]
  before_filter :timer_permission, :only => :toggle_timer
  before_filter :verify_permission, :only => [:create, :index, :show, :edit, :update, :destroy, :toggle_timer ] 
  before_filter :check_agents_in_account, :only =>[:create]
  before_filter :set_mobile, :only =>[:index , :create , :update , :show]
  before_filter :set_native_mobile , :only => [:create , :index, :destroy]

  rescue_from ActiveRecord::UnknownAttributeError , :with => :handle_error

  def index
    unless @ticket.nil?
      @time_sheets = @ticket.time_sheets 
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
        render :json=>@time_sheets, :status => find_status #temp_hack. Will be addressed in API_Versioning
      end
      format.mobile do
        render :json=>@time_sheets.all(:order => "executed_at").to_json()
      end
      format.nmobile do
        time_entries = Array.new
        @time_sheets.each do |time_entry|
          time_entries << time_entry.to_mob_json
        end 
        render :json => time_entries
      end
    end
  end

  def new
    render :layout => false
  end

  def edit
    render :layout => false
  end
  
  def create
    hours_spent = params[:time_entry][:hhmm]
    params[:time_entry].delete(:hhmm)

    update_running_timer params[:time_entry][:user_id] if hours_spent.blank?
    
    sync_installed_apps #added to sync the installed apps

    #Added for API calls where user will not be knowing the id for ticket, instead provide only the display id.
    #Need to think about another way of handling this
    if params[:time_entry][:workable_id].blank? #this will be always present when called from portal's 'Add Time'
      check_ticket = current_account.tickets.find_by_display_id(params[:ticket_id]) unless params[:ticket_id].nil?
      unless check_ticket.nil?
        params[:time_entry][:workable_id] = check_ticket.id
      else
          raise ActiveRecord::RecordNotFound
      end
    end

    time_entry =  { "start_time" => Time.zone.now(),
                    "executed_at" => Time.zone.now(),
                    "time_spent" => convert_duration(hours_spent),
                    "timer_running" => hours_spent.blank?
                  }.merge(params[:time_entry])
    
    @time_entry = scoper.new(time_entry)    #throws unknown attribute error
    if @time_entry.save!
      nmobile_response = {:success => true} 
      respond_to_format(@time_entry, nmobile_response)
    end
  end
   
  def show
     respond_to_format @time_entry
  end

  def update  
    hours_spent = params[:time_entry][:hhmm]
    params[:time_entry].delete(:hhmm)
    time_entry = params[:time_entry].merge!({:time_spent => convert_duration(hours_spent)})

    unless params[:time_entry][:user_id].blank?
      raise ActiveRecord::RecordNotFound if current_account.agents.find_by_user_id(params[:time_entry][:user_id]).blank? 
    end

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
     sync_installed_apps
     respond_to_format @time_entry
  end
  
  # possible dead code
  def time_sheets_for_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:id])
    @time_sheets = @ticket.time_sheets.group_by(&:group_by_day_criteria) || []
    render :partial => "helpdesk/time_sheets/time_sheets_for_ticket"
  end
  
  # possible dead code
  def time_sheets_by_agents
     @ticket = current_account.tickets.find_by_display_id(params[:id])
     @items = @ticket.time_sheets.group_by(&:user) || [] 
     #need to render a new partial- u may iterate as--@items.each{|key,val| val.each{|t| puts t.note}}
  end

  def destroy
    @time_entry.destroy
    mobile_response = {:success => true}
    respond_to_format @time_entry , mobile_response
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
     
  # possible dead code
  def get_time_in_second time_hour
    s = time_hour.to_f * 60 * 60 
  end

  def convert_duration(duration)
    if duration =~ /^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/
      time_pieces = duration.split(":")
      hours = time_pieces[0].to_i
      minutes = (time_pieces[1].to_f/60.0)

      duration = hours + minutes
    end

    (duration.to_f * 60 * 60).to_i
  end
  
  def load_time_entry
    @time_entry = scoper.find(params[:id])
  end
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end
  
  # possible dead code
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

  def sync_installed_apps
    Integrations::TimeSheetsSync.applications.each do |app_name|
      installed_app = current_account.installed_applications.with_name(app_name)
      next if installed_app.blank?  
      Integrations::TimeSheetsSync.send(app_name,installed_app.first,@time_entry,current_user) unless @time_entry.blank?
      Integrations::TimeSheetsSync.send(app_name,installed_app.first,@time_cleared,current_user) unless @time_cleared.blank?
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

  def respond_to_format result,mobile_response = nil
    respond_to do |format|
      format.js
      format.html
      format.nmobile do
        render :json => mobile_response.to_json and return
      end
      format.xml do 
        render :xml => result.to_xml and return 
      end
      format.mobile {
          render :json => {:success => true, :item => result}.to_json
      }
      format.json do
        if(result.frozen?)
          render :json => {:success => true}
        else
          render :json => result.to_json and return 
        end
      end
    end
  end

  #API Method
  def get_time_sheets
    normalize_params
    # start date is set to the zero if nothing is specified similarly End date is set to current time.
    start_date = validate_time(params[:start_date]) ? Time.zone.parse(params[:start_date]): Helpdesk::TimeSheet::FILTER_OPTIONS[:executed_after] 
    end_date =  validate_time(params[:end_date]) ? Time.zone.parse(params[:end_date]): Time.zone.now.to_time 
    
    #agent/email name 
    email = params[:email]
    unless email.blank?
      requester = current_account.user_emails.user_for_email(email) 
      unless requester.nil? 
        params[:agent_id] = requester.agent.user_id if requester.agent?
        Rails.logger.debug "Timesheets API::get_time_sheets:  params[:email] is a agent =>" + (requester.agent?).to_s
      end
    end
    company_id = params[:company_id] || [] 
    unless params[:company_name].blank?
      company = current_account.companies.find_by_name(params[:company_name])
      # raise ActiveRecord::RecordNotFound if(company.blank?)#indication company not found
      company_id = company.id unless company.nil?
    end
    agent_id = params[:agent_id] || []

    billable = (!params[:billable].blank?) ? [params[:billable].to_s.to_bool] : true
    #search by contact
    contact = current_account.user_emails.user_for_email(params[:contact_email]) unless params[:contact_email].blank?
    
    #temp hack for invalid/non existent contact email to provide backward compatibility.
    if contact.nil? && params[:contact_email]
      @time_sheets = []
      return 
    end
    #company_id and agent_id if passed null will return all data.  
    unless contact.nil?
      Rails.logger.debug "Timesheets API::get_time_sheets: contact => "+contact.id.to_s() +" agent_id =>"+ agent_id.to_s() + " billable=>" + billable.to_s+ " from =>"+ start_date.to_s+ " till=> " + end_date.to_s
      @time_sheets = current_account.time_sheets.for_contacts_with_id(contact.id).by_agent(agent_id).created_at_inside(start_date,end_date).hour_billable(billable).includes(:user, :workable => {:requester => :company})
    else
      Rails.logger.debug "Timesheets API::get_time_sheets: company_id=> "+company_id.to_s() +" agent_id =>"+ agent_id.to_s() + " billable=>" + billable.to_s+ " from =>"+ start_date.to_s+ " till=> " + end_date.to_s
      @time_sheets = current_account.time_sheets.for_companies(company_id).by_agent(agent_id).created_at_inside(start_date,end_date).hour_billable(billable).includes(:user, :workable => {:requester => :company})
    end
  end

  def validate_time time
    begin
      parsed_time = Time.zone.parse(time)
    rescue
      return false 
    end
  end

  def find_status
    @time_sheets.kind_of?(Hash) ? 400 : 200
  end

  def check_agents_in_account
    #ADDED for SECURITY ISSUE: Users from other account are allowed to be added
    #by specifying user_id in the api.
   handle_error(StandardError.new("Agent not found for given user_id")) if current_account.agents.find_by_user_id(params[:time_entry][:user_id]).blank?
  end

  def create_permission
    if(!privilege?(:edit_time_entries) && params[:time_entry][:user_id].to_i != current_user.id)
      flash[:error] = t('flash.tickets.timesheet.create_error')
      respond_to do |format|
        format.js
      end
    end
  end

  def timer_permission
    if(!privilege?(:edit_time_entries) && @time_entry.user_id != current_user.id)
      flash[:error] = t('flash.tickets.timesheet.create_error')
      respond_to do |format|
        format.js
      end
    end
  end

  def validate_params
    params[:time_entry].delete('executed_at') unless validate_time(params[:time_entry][:executed_at])
  end

  def verify_permission
    if @ticket || (@time_entry && @time_entry.workable.is_a?(Helpdesk::Ticket))
      ticket = @ticket || @time_entry.workable
      verify_ticket_permission(ticket)
    end
  end

end

