class Admin::ChatWidgetsController < Admin::AdminController

  include ChatHelper
  before_filter { |c| c.requires_feature :chat }

  def index
    if chat_activated?
      @widgets = current_account.chat_widgets
      @chat_enabled = current_account.chat_setting.active
      @chat_active = true
    else
      @chat_active = false
    end
  end

  def edit
    @widget = current_account.chat_widgets.find(params[:id])
  end

  def update 
    widget = current_account.chat_widgets.find(params[:id])
    if widget
      if widget.update_attributes({ :business_calendar_id => params[:business_calendar_id],
                                    :show_on_portal => params[:show_on_portal],
                                    :portal_login_required => params[:portal_login_required] })
        # Sending the Business Calendar Data to the FreshChat DB.
        business_cal_id = params[:business_calendar_id] 
        calendar_data  = business_cal_id.blank? ? nil : JSON.parse(BusinessCalendar.find(business_cal_id).to_json({:only => [:time_zone, :business_time_data, :holiday_data]}))['business_calendar']
        
        Resque.enqueue(Workers::Livechat, 
          {
            :user_id => current_user.id,
            :worker_method => "update_widget", 
            :siteId => params[:siteId],
            :widget_id => widget.widget_id,
            :attributes => { :business_calendar => calendar_data, :proactive_chat => params[:proactive_chat], :proactive_time => params[:proactive_time], :routing => params[:routing]}
          }
        )
        render :json => {:status => "success"}
      else
        render :json => {:status => "error", :message => "Error while updating widget"}
      end
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end
  end

end