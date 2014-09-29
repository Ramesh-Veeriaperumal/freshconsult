class Admin::DynamicNotificationTemplatesController < Admin::AdminController

	def update
    dynamic_notification = (params[:id].nil?) ? current_account.dynamic_notification_templates.new : 
                                                current_account.dynamic_notification_templates.find_by_id(params[:id])
		
		if dynamic_notification.update_attributes(params[:dynamic_notification_template])
  		flash[:notice] = t(:'flash.email_notifications.update.success')
  	else
   		flash[:notice] = t(:'flash.email_notifications.update.failure') 	
   	end	

    template_type = ( dynamic_notification.category == DynamicNotificationTemplate::CATEGORIES[:agent]) ? "agent_template" :
      ( dynamic_notification.email_notification.notification_type == EmailNotification::DEFAULT_REPLY_TEMPLATE ?
        "reply_template" : "requester_template" )

    respond_to do |format|
      format.html { 
        redirect_to redirect_url(template_type)
      }
      format.js 
    end  
	end	

private
  def redirect_url(template_type)
    language = DynamicNotificationTemplate::LANGUAGE_MAP_KEY[params[:dynamic_notification_template][:language].to_i].to_s

     url = admin_edit_notification_path(
          :id =>params[:dynamic_notification_template][:email_notification_id], 
          :type => template_type
          )+"#"+language
  end
end	
