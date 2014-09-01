class Admin::DynamicNotificationTemplatesController < Admin::AdminController

	def update
    dynamic_notification = (params[:id].nil?) ? current_account.dynamic_notification_templates.new : 
                                                current_account.dynamic_notification_templates.find_by_id(params[:id])
		
		if dynamic_notification.update_attributes(params[:dynamic_notification_template])
  		flash[:notice] = t(:'flash.email_notifications.update.success')
  	else
   		flash[:notice] = t(:'flash.email_notifications.update.failure') 	
   	end	
    respond_to do |format|
      format.html { 
        redirect_to redirect_url
      }
      format.js 
    end  
	end	

private
  def redirect_url
    language = DynamicNotificationTemplate::LANGUAGE_MAP_KEY[params[:dynamic_notification_template][:language].to_i].to_s

    category = params[:dynamic_notification_template][:category]
     url = admin_edit_notification_path(
          :id =>params[:dynamic_notification_template][:email_notification_id], 
          :type => (category == DynamicNotificationTemplate::CATEGORIES[:agent].to_s) ? 
            "agent_template" : (params[:dynamic_notification_template][:subject].nil? ? "reply_template" : "requester_template")
          )+"#"+language
  end
end	
