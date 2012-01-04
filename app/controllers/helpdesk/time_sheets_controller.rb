class Helpdesk::TimeSheetsController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }  
  before_filter :load_time_entry, :only => [ :edit, :update, :destroy, :toggle_timer ]  
  
  def new
    update_running_timer params[:time_entry][:ticket_id]
    create_time_entry
    @time_sheet.save
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
        update_running_timer @time_entry.ticket.id if @time_entry.ticket
        @time_entry.update_attributes({ :timer_running => true, :start_time => Time.zone.now })
     end
  end
  
  def time_sheets_for_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:id])
    @time_sheets = @ticket.time_sheets || []
    render :partial => "helpdesk/time_sheets/time_sheets_for_ticket"
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
  
  def total_time_spent time_sheets
    total_time_in_sec = time_sheets.collect{|t| t.time_spent}.sum
    hours = total_time_in_sec.div(60*60)
    minutes_as_percent = (total_time_in_sec.div(60) % 60)*(1.667).round
    total_time = hours.to_s()+"."+ minutes_as_percent.to_s()
    total_time
  end
  
  #Following method will stop running timer..
  def update_running_timer ticket_id
    ticket  = current_account.tickets.find(ticket_id)
    @time_cleared = ticket.time_sheets.find_by_timer_running(true);
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
    time_entry = params[:time_entry].merge!({:start_time => Time.zone.now(),
                                            :time_spent => get_time_in_second(hours_spent),
                                            :timer_running => true,
                                            :billable => true})
    @time_sheet = scoper.new(time_entry)
  end
  
end

