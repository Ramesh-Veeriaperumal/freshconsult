class Admin::EmailNotificationsController < Admin::AdminController 
  
  def index
    e_notifications = current_account.email_notifications
    by_type = Hash[*e_notifications.map { |n| [n.notification_type, n] }.flatten]
    
    @notifications = [
      { :type => t('user_activation_email'), :requester => true, :agent => true, :placeholder => false, :agentSelect => false,
                  :obj => by_type[EmailNotification::USER_ACTIVATION] },
      { :type => t('password_reset_email'), :requester => true, :agent => true, :placeholder => false, :agentSelect => false, :userSelect => false,
                  :obj => by_type[EmailNotification::PASSWORD_RESET] },
      { :type => t('new_ticket_created'), :requester => true, :agent => true, :agentSelect => true,
                  :obj => by_type[EmailNotification::NEW_TICKET] },
      { :type => t('tkt_assigned_to_group'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_GROUP] },
      { :type => t('tkt_unattended_in_grp'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_UNATTENDED_IN_GROUP] },
      { :type => t('tkt_assigned_to_agent'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_AGENT] },
      { :type => t('first_response_sla'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::FIRST_RESPONSE_SLA_VIOLATION] },
      { :type => t('requester_replies'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::REPLIED_BY_REQUESTER] },
      { :type => t('resolution_time_sla'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::RESOLUTION_TIME_SLA_VIOLATION] },
      { :type => t('agent_solves_tkt'), :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::TICKET_RESOLVED] },
      { :type => t('agent_closes_tkt'), :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::TICKET_CLOSED] },
      { :type => t('requester_reopens'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_REOPENED] }]
                  
  @agent_hash = {:options => get_agent_options }
  end

  def get_agent_options
    current_account.agents.collect { |au| [au.user.id, au.user.name] }
  end

  def update
    new_data = ActiveSupport::JSON.decode(params[:update][:notification_data])
    current_account.email_notifications.each do |n|
      n.update_attributes! new_data[n.id.to_s]
      update_agents n if (n.notification_type == EmailNotification::NEW_TICKET)
    end
      
    flash[:notice] = t(:'flash.email_notifications.update.success')
    redirect_back_or_default admin_email_notifications_url
  end
  
  def update_agents e_notification
    notification_agents = e_notification.email_notification_agents
    notification_agents.each do |agent|
      agent.destroy
    end
    agents_data = ActiveSupport::JSON.decode(params[:update][:notifyagents_data])
    agents_data[e_notification.id.to_s].each do |user_id|
      n_agent = current_account.users.technicians.find(user_id).email_notification_agents.build()
      n_agent.email_notification = e_notification
      n_agent.account = current_account
      n_agent.save  
    end
  end
   
end
