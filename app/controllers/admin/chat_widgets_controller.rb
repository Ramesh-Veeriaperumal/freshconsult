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
    @widget = current_account.chat_widgets.find(params[:id])
    if @widget
      if @widget.update_attributes(params[:chat_setting])
        #####
        # Sending the Business Calendar Data to the FreshChat DB.
        #####
        Rails.logger.debug " Sending the Business Calendar Data to FreshChat through Resque"
        proactive_chat = params[:proactive_chat]
        proactive_time = params[:proactive_time]
        businessCal_id = params[:chat_setting][:business_calendar_id] 
        @CalendarData = businessCal_id.blank? ? nil : JSON.parse(BusinessCalendar.find(businessCal_id).to_json({:only => [:time_zone, :business_time_data, :holiday_data]}))['business_calendar']
        Resque.enqueue(Workers::Freshchat, {:worker_method => "update_widget", :siteId => params[:siteId],
                                            :widget_id => @widget.widget_id,
                                            :attributes => { :business_calendar => @CalendarData, 
                                                             :proactive_chat => proactive_chat, 
                                                             :proactive_time => proactive_time,
                                                             :routing => params[:routing]
                                                            }})
        render :json => {:status => "success"}
      else
        render :json => {:status => "error", :message => "Error while updating widget"}
      end
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end
  end

end