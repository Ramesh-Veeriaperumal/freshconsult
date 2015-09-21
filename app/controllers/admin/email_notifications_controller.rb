class Admin::EmailNotificationsController < Admin::AdminController 
  
  def index
    e_notifications = current_account.email_notifications 

    @agent_notifications = e_notifications.select { |n| n.visible_to_agent? }
    
    @user_notifications = e_notifications.select { |n| n.visible_to_requester? }
    
    @reply_templates = e_notifications.select { |n| n.reply_template? }

    @cc_notifications = e_notifications.select { |n| n.cc_notification? }
  end
  
  def update
    email_notification = current_account.email_notifications.find(params[:id])
  
    if params[:outdated] 
      if params[:requester]
        params[:email_notification][:outdated_requester_content] = true
        DynamicNotificationTemplate.where(
          "email_notification_id = #{email_notification.id} and category = #{DynamicNotificationTemplate::CATEGORIES[:requester]} ").update_all({:outdated => true})            
      elsif params[:agent]
        params[:email_notification][:outdated_agent_content] = true
        DynamicNotificationTemplate.where(
        "email_notification_id = #{email_notification.id} and category = #{DynamicNotificationTemplate::CATEGORIES[:agent]} ").update_all({:outdated => true})
      end   
    end
    if email_notification.update_attributes(params[:email_notification])
      flash[:notice] = t(:'flash.email_notifications.update.success')
    else
      flash[:notice] = t(:'flash.email_notifications.update.failure')
    end

    respond_to do |format|
      format.html { redirect_to :back }
      format.js      
    end
  end

  def edit  
    @email_notification = current_account.email_notifications.find(params[:id])
    notification_type = @email_notification.notification_type
    @supported_languages = current_account.account_additional_settings.supported_languages
    @default_language = current_account.language 
    @type = params[:type]
    url_check = @email_notification.fetch_template || params[:type]
    if @email_notification.send(url_check).nil?
      flash[:error] = t(:'flash.email_notifications.update.does_not_exist')
      redirect_to admin_email_notifications_path
    end
  end   

  def update_agents 
    e_notification = current_account.email_notifications.find(params[:id])
    notification_agents = e_notification.email_notification_agents
    notification_agents.each do |agent|
      agent.destroy
    end
    agents_data = ActiveSupport::JSON.decode(params[:email_notification_agents][:notifyagents_data])
    agents_data[e_notification.id.to_s].each do |user_id|
      n_agent = current_account.users.technicians.find(user_id).email_notification_agents.build()
      n_agent.email_notification = e_notification
      n_agent.account = current_account
      n_agent.save  
    end
    redirect_to :back
  end

end
