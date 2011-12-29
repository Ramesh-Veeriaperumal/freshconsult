class Helpdesk::TimeSheetsController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }
  
  def index
  end

  def new
    update_running_timer params[:time_entry][:ticket_id]
    create_time_entry
    if @time_sheet.save
       render :new
     else
       render :json => { :success => false, :errors => @time_sheet.errors.to_json } 
     end
  end

  def edit
    @time_entry = scoper.find(params[:id])
    render :edit
  end

  def update  
    hours_spent = params[:time_entry][:hours]
    params[:time_entry].delete(:hours)
    time_entry = params[:time_entry].merge!({:time_spent => get_time_in_second(hours_spent.to_i())})
    @time_entry = scoper.find(params[:id])
    if @time_entry.update_attributes(time_entry)
       render :partial => "/helpdesk/time_sheets/time_entry", :object => @time_entry
    end    
  end

  def destroy
    @time_entry = scoper.find(params[:id])
    @time_entry.destroy
  end
  
  def create_timer
   update_running_timer params[:time_entry][:ticket_id]
   create_time_entry 
   if @time_sheet.save
      time_entry =  render_to_string (:partial => "helpdesk/time_sheets/time_entry_item", :locals => { :time_entry => @time_sheet })
      render :json => { :success => true, :raw => time_entry , :total_time_spent => total_time_spent(@time_sheet.ticket.time_sheets || []) }
    else
      render :json => { :success => false, :errors => @time_sheet.errors.to_json } 
    end    
  end
  
  def start_timer
    @time_sheet = scoper.find(params[:id])    
    update_running_timer @time_sheet.ticket.id if @time_sheet.ticket
    if @time_sheet.update_attribute(:timer_running , true)
       render :json => { :success => true, :message => "Successfully started the timer" }
    else
      render :json => { :success => false, :errors => @time_sheet.errors.to_json } 
    end
  end
  
   def stop_timer
    @time_sheet = scoper.find(params[:id])   
    if @time_sheet.update_attributes({:timer_running => false , :time_spent => calculate_time_spent(@time_sheet)})
       render :json => { :success => true, :message => "Successfully stopped the timer" }
    else
      render :json => { :success => false, :errors => @time_sheet.errors.to_json } 
    end
  end
  
  #Following method will stop running timer..
  def update_running_timer ticket_id
    ticket  = current_account.tickets.find(ticket_id)
    time_sheet = ticket.time_sheets.find_by_timer_running(true);
    time_sheet.update_attributes({:timer_running => false , :time_spent => calculate_time_spent(time_sheet) }) if time_sheet
    #ticket.time_sheets.update_all(:timer_running => false)
  end
  
  def calculate_time_spent time_sheet
    from_time = time_sheet.start_time
    to_time = Time.zone.now
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    running_time =  ((to_time - from_time).abs).round 
    return (time_sheet.time_spent + running_time)
  end
  
  def create_time_entry
    hours_spent = params[:time_entry][:hours]
    params[:time_entry].delete(:hours)
    time_entry = params[:time_entry].merge!({:start_time => Time.zone.now(),
                                            :time_spent => get_time_in_second(hours_spent.to_i()),
                                            :timer_running => true,
                                            :billable => true})
    @time_sheet = scoper.new(time_entry)  
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
      s = time_hour * 60 * 60 
  end
  
  def total_time_spent time_sheets
    total_time_in_sec = time_sheets.collect{|t| t.time_spent}.sum
    hours = total_time_in_sec.div(60*60)
    minutes_as_percent = (total_time_in_sec.div(60) % 60)*(1.667).round
    total_time = hours.to_s()+"."+ minutes_as_percent.to_s()
    total_time
  end

end

