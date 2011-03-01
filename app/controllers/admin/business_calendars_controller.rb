class Admin::BusinessCalendarsController <  Admin::AdminController  
   
  def index
    @business_calendars = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})    
    logger.debug "@business_calendars :: index: business_time_data #{@business_calendars.business_time_data.inspect} \n and holidays:: #{@business_calendars.holidays.inspect}"
    
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @business_calendars }
    end
  end
 
  def update
    
    logger.debug "params are:: #{params.inspect}"
   
    holidays = ActiveSupport::JSON.decode params[:business_calenders][:holidays]
   
    business_time = Hash.new
    
    business_time[:beginning_of_workday] = params[:business_calenders][:beginning_of_workday]
    business_time[:end_of_workday]       =  params[:business_calenders][:end_of_workday]
    business_time[:weekdays]             = ActiveSupport::JSON.decode params[:business_calenders][:weekdays]
    business_time[:fullweek]             = params[:business_calenders][:fullweek]
       
    logger.debug "business_time :: #{business_time.inspect}"
    
    logger.debug "holidays :: #{holidays.inspect}"    
    
    @business_cal = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})
    
   if @business_cal.update_attributes(:business_time_data =>business_time, :holidays =>holidays )     
     flash[:notice] = "Business Calendar has been updated successfully"
     redirect_back_or_default :action => 'index'
     
   else
     flash[:notice] = "Failed to update Business Calendar "
     redirect_back_or_default :action => 'index'
   end
    
   
  end

end
