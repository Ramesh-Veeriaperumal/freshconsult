class Admin::BusinessCalendarsController <  Admin::AdminController
  
  before_filter { |c| c.requires_feature :business_hours }
   
  def index
    @business_calendars = current_account.business_calendar
    logger.debug %(@business_calendars :: index: business_time_data #{@business_calendars.business_time_data.inspect}
     and holidays:: #{@business_calendars.holiday_data.inspect})
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @business_calendars }
    end
  end
 
  def update
    holiday_data = ActiveSupport::JSON.decode params[:business_calenders][:holiday_data]
    weekdays = ActiveSupport::JSON.decode params[:business_calenders][:weekdays]
    working_hours = params[:business_time_data]["working_hours"]

    business_time = Hash.new
    business_time[:weekdays] = weekdays.map {|i| i.to_i}
    business_time[:working_hours] = Hash.new
      
    business_time[:weekdays].each do |n|
      business_time[:working_hours][n] = Hash.new
      business_time[:working_hours][n] = working_hours[n.to_s].symbolize_keys
      if (business_time[:working_hours][n][:end_of_workday].eql?("12:00 am"))
        business_time[:working_hours][n][:end_of_workday] = "11:59:59 pm"
      end
    end

    business_time[:fullweek] = "true".eql?(params[:business_calenders][:fullweek])
    
    if business_time[:fullweek]
      business_time[:weekdays] = [0, 1, 2, 3, 4, 5, 6]

      business_time[:weekdays].each do |n|
        business_time[:working_hours][n] = Hash.new
        business_time[:working_hours][n][:beginning_of_workday] = "00:00:00 am"
        business_time[:working_hours][n][:end_of_workday] = "11:59:59 pm"
      end
    end 
    
    
    @business_cal = current_account.business_calendar
    
    if @business_cal.update_attributes(:business_time_data =>business_time, :holiday_data =>holiday_data )
     flash[:notice] = t(:'flash.business_hours.update.success')
    else
     flash[:notice] = t(:'flash.business_hours.update.failure')
    end

    redirect_back_or_default :action => 'index'
  end

end
