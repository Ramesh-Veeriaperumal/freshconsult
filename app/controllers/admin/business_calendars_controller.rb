class Admin::BusinessCalendarsController <  Admin::AdminController  
  
  before_filter { |c| c.requires_feature :business_hours }
   
  def index
    @business_calendars = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})    
    logger.debug "@business_calendars :: index: business_time_data #{@business_calendars.business_time_data.inspect} \n and holidays:: #{@business_calendars.holiday_data.inspect}"
    
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @business_calendars }
    end
  end
 
  def update
    
   
    holiday_data = ActiveSupport::JSON.decode params[:business_calenders][:holiday_data]
    weekdays = ActiveSupport::JSON.decode params[:business_calenders][:weekdays]
    full_week = params[:business_calenders][:fullweek]
    
    business_time = Hash.new
    
    business_time[:beginning_of_workday] = params[:business_calenders][:beginning_of_workday] 
    business_time[:end_of_workday] =  params[:business_calenders][:end_of_workday]
    business_time[:weekdays] = weekdays.map {|i| i.to_i}
    business_time[:fullweek] = false
    
    if "true".eql?(full_week)      
       business_time[:weekdays] = [1, 2, 3, 4, 5, 6, 7]
       business_time[:fullweek] = true
       business_time[:beginning_of_workday]="00:00:00 am"
       business_time[:end_of_workday] = "11:59:59 pm"
    end 
    
    @business_cal = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})
    
   if @business_cal.update_attributes(:business_time_data =>business_time, :holiday_data =>holiday_data )     
     flash[:notice] = t(:'flash.business_hours.update.success')
     redirect_back_or_default :action => 'index'
     
   else
     flash[:notice] = t(:'flash.business_hours.update.failure')
     redirect_back_or_default :action => 'index'
   end
    
   
  end

end
