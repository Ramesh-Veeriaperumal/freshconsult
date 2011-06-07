class Admin::EmailNotificationsController < Admin::AdminController 
  
  def index
    e_notifications = current_account.email_notifications
    by_type = Hash[*e_notifications.map { |n| [n.notification_type, n] }.flatten]
    
    @notifications = [
      { :type => t('user_activation_email'), :requester => true, :agent => true, :placeholder => false, :agentSelect => false,
                  :obj => by_type[EmailNotification::USER_ACTIVATION] },
      { :type => t('password_reset_email'), :requester => true, :agent => true, :placeholder => false, :agentSelect => false, :userSelect => false,
                  :obj => by_type[EmailNotification::PASSWORD_RESET] },
      { :type => t('new_ticket_created'), :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::NEW_TICKET] },
      { :type => t('tkt_assigned_to_group'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_GROUP] },
      { :type => t('tkt_unattended_in_grp'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_UNATTENDED_IN_GROUP] },
      { :type => t('tkt_assigned_to_agent'), :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_AGENT] },
      { :type => t('agent_adds_comment'), :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::COMMENTED_BY_AGENT] },
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
  end

  def update      
      new_data = ActiveSupport::JSON.decode(params[:update][:notification_data])
      current_account.email_notifications.each do |n|
        n.update_attributes! new_data[n.id.to_s]
      end
      
      flash[:notice] = t(:'flash.email_notifications.update.success')
      redirect_back_or_default admin_email_notifications_url
  end
   
end
