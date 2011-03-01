class Admin::BusinessCalendarsController < ApplicationController
  
  before_filter :set_selected_tab
  
  def index
    @business_calendars = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})    
    logger.debug "@business_calendars :: index: business_time_data #{@business_calendars.business_time_data.inspect} \n and holidays:: #{@business_calendars.holidays.inspect}"
    
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @business_calendars }
    end
  end

  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  def update
    
   
    holidays = ActiveSupport::JSON.decode params[:business_calenders][:holidays]
    weekdays = ActiveSupport::JSON.decode params[:business_calenders][:weekdays]
    full_week = params[:business_calenders][:fullweek]
    
    business_time = Hash.new
    
    business_time[:beginning_of_workday] = params[:business_calenders][:beginning_of_workday]
    business_time[:end_of_workday] =  params[:business_calenders][:end_of_workday]
    business_time[:weekdays] = weekdays.map {|i| i.to_i}
    business_time[:fullweek] = eval(full_week)
   
    
    @business_cal = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})
    
   if @business_cal.update_attributes(:business_time_data =>business_time, :holidays =>holidays )     
     flash[:notice] = "Business Calendar has been updated successfully"
     redirect_back_or_default :action => 'index'
     
   else
     flash[:notice] = "Failed to update Business Calendar "
     redirect_back_or_default :action => 'index'
   end
    
   
  end

  def destroy
  end

protected

def set_selected_tab
      @selected_tab = 'Admin'
end

end
