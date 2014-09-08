class Admin::ChatSettingController < Admin::AdminController

  include ChatHelper
  before_filter { |c| c.requires_feature :chat }

  def index
    unless feature?(:chat)
      render_404
    end
  end

  def update
    @chat = current_account.chat_setting || ChatSetting.new

    if @chat.update_attributes(params[:chat_setting])
    	@chat.save
      @status = "success"
      render_result

      #####
      # Sending the Business Calendar Data to the FreshChat DB.
      #####
      Rails.logger.debug " Sending the Business Calendar Data to FreshChat through Resque"
      proactive_chat = params[:proactive_chat]
      proactive_time = params[:proactive_time]
      businessCal_id = params[:chat_setting][:business_calendar_id] 

      @CalendarData = (businessCal_id.eql? '0') ? nil : BusinessCalendar.find(businessCal_id).to_json({:only => [:time_zone, :business_time_data, :holiday_data]})
      Resque.enqueue(Workers::FreshchatCalendarUpdate, {:type => "update", :display_id => params[:siteId], :calendarData => @CalendarData, :proactive_chat => proactive_chat, :proactive_time => proactive_time})
    else
    	@status = "error"
      render_result
  	end
  end

  private

  def render_result
    respond_to do |format|
      format.json{
        render :json => {:status => @status}
      }
    end
  end
end