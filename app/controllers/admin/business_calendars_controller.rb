class Admin::BusinessCalendarsController <  Admin::AdminController

  before_filter { access_denied unless current_account.sla_management_v2_enabled? }
  before_filter :load_object, :only => [:update, :destroy, :edit]

  def load_object
    @business_calendar = current_account.business_calendar.find(params[:id])
  end
   
  def index
    if current_account.multiple_business_hours_enabled?
      @business_calendars = current_account.business_calendar.order('name')

      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => @business_calendars }
      end
    else
      redirect_to :action => 'edit', :id => current_account.business_calendar.default.first.id
    end
    
  end

  def new
    if current_account.multiple_business_hours_enabled?
      @business_calendar = current_account.business_calendar.new    
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @business_calendar }
      end
    else
      redirect_to :action => 'edit', :id => current_account.business_calendar.default.first.id
    end
  end

  def create
    process_data
    @business_calendar = current_account.business_calendar.new(
                    :business_time_data =>@business_time, :holiday_data =>@holiday_data,
                     :name => @name, :description => @description, :time_zone => @time_zone )

    @business_calendar.account_id = current_account.id

    if @business_calendar.save
      flash[:notice] = t(:'flash.business_hours.create.success')
    else
      flash[:notice] = t(:'flash.business_hours.create.failure')
    end
    redirect_back_or_default :action => 'index'
  end

  def edit
      respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @business_calendar }
    end
  end
 
  def update
    process_data
    
    if @business_calendar.update_attributes(:business_time_data =>@business_time, :holiday_data =>@holiday_data,
                                            :name => @name, :description => @description, :time_zone => @time_zone )
     flash[:notice] = t(:'flash.business_hours.update.success')
    else
     flash[:notice] = t(:'flash.business_hours.update.failure')
    end

    redirect_back_or_default :action => 'index'
  end

  def destroy
    if @business_calendar.is_default?
      flash[:notice] = t(:'flash.general.destroy.failure', :human_name => "Business Calendar")
        redirect_to(:action => 'index') and return
    else
      @business_calendar.destroy
    end
    
    respond_to do |format|
      format.html { 
        flash[:notice] = t(:'flash.general.destroy.success', :human_name => "Business Calendar")
        redirect_to(:action => 'index') and return }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  def holidays
    calendar_id = params["calendar_id"]
    google_service_obj = IntegrationServices::Services::GoogleService.new(nil, {"calendar_id" => calendar_id }, :user_agent => request.user_agent)
    service_response = google_service_obj.receive('list_holidays')
    if service_response[:error].blank?
      render :json => service_response[:holidays].to_json
    else
      Rails.logger.info "Unable to fetch holidays for #{calendar_id}, Trace: #{service_response[:error_message]}"
      return []
    end
  end

  private

    def process_data
      @holiday_data = ActiveSupport::JSON.decode params[:business_calenders][:holiday_data]
      weekdays = ActiveSupport::JSON.decode params[:business_calenders][:weekdays]
      working_hours = params[:business_time_data]["working_hours"]
      @time_zone = params[:business_calenders][:time_zone] || current_account.time_zone
      
      @name = params[:business_calenders]["name"] if params[:business_calenders]
      @description = params[:business_calenders]["description"] if params[:business_calenders]
      @business_time = Hash.new
      @business_time[:weekdays] = weekdays.map {|i| i.to_i}
      @business_time[:working_hours] = Hash.new
        
      @business_time[:weekdays].each do |n|
        @business_time[:working_hours][n] = Hash.new
        @business_time[:working_hours][n] = working_hours[n.to_s].symbolize_keys
        if (@business_time[:working_hours][n][:end_of_workday].eql?("12:00 am"))
          @business_time[:working_hours][n][:end_of_workday] = "11:59:59 pm"
        end
      end

      @business_time[:fullweek] = "true".eql?(params[:business_calenders][:fullweek])
      
      if @business_time[:fullweek]
        @business_time[:weekdays] = [0, 1, 2, 3, 4, 5, 6]

        @business_time[:weekdays].each do |n|
          @business_time[:working_hours][n] = Hash.new
          @business_time[:working_hours][n][:beginning_of_workday] = "00:00:00 am"
          @business_time[:working_hours][n][:end_of_workday] = "11:59:59 pm"
        end
      end 
    end

end
