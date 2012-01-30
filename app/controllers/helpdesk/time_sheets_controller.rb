class Helpdesk::TimeSheetsController < ApplicationController
  
  before_filter { |c| c.requires_feature :timesheets }
  before_filter { |c| c.requires_permission :manage_tickets }  
  before_filter :load_time_entry, :only => [ :edit, :update, :destroy, :toggle_timer ] 
  before_filter :load_ticket, :only => [:index, :edit, :update, :toggle_timer] 
  
  def index    
    @time_sheet = @ticket.time_sheets
    render :index, :layout => false
  end
  
  def new
    create_time_entry
    @time_entry.save
  end
   
  def update  
    hours_spent = params[:time_entry][:hours]
    params[:time_entry].delete(:hours)
    time_entry = params[:time_entry].merge!({:time_spent => get_time_in_second(hours_spent)})
    if @time_entry.update_attributes(time_entry)
        render :partial => "/helpdesk/time_sheets/time_entry", :object => @time_entry
    end
  end 
  
  def toggle_timer     
     if @time_entry.timer_running
        @time_entry.update_attributes({ :timer_running => false, :time_spent => calculate_time_spent(@time_entry) })        
     else
        update_running_timer @time_entry.user_id
        @time_entry.update_attributes({ :timer_running => true, :start_time => Time.zone.now })
     end
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
  
  def create_time_entry
    hours_spent = params[:time_entry][:hours]
    params[:time_entry].delete(:hours)

    update_running_timer params[:time_entry][:user_id] if hours_spent.blank?

    time_entry = params[:time_entry].merge!({:start_time => Time.zone.now(),
                                             :executed_at => Time.zone.now(),
                                             :time_spent => get_time_in_second(hours_spent),
                                             :timer_running => hours_spent.blank?,
                                             :billable => true})
    @time_entry = scoper.new(time_entry)
  end
  
end

