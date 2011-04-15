class Admin::EmailNotificationsController < Admin::AdminController 
  
  def index
    e_notifications = current_account.email_notifications
    by_type = Hash[*e_notifications.map { |n| [n.notification_type, n] }.flatten]
    
    @notifications = [
      { :type => "User Activation Email", :requester => true, :agent => true, :placeholder => false, :agentSelect => false,
                  :obj => by_type[EmailNotification::USER_ACTIVATION] },
      { :type => "Password Reset Email", :requester => true, :agent => true, :placeholder => false, :agentSelect => false, :userSelect => false,
                  :obj => by_type[EmailNotification::PASSWORD_RESET] },
      { :type => "New Ticket Created", :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::NEW_TICKET] },
      { :type => "Ticket assigned to Group", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_GROUP] },
      { :type => "Ticket unattended in Group", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_UNATTENDED_IN_GROUP] },
      { :type => "Ticket assigned to Agent", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_AGENT] },
      { :type => "Agent adds comment to Ticket", :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::COMMENTED_BY_AGENT] },
      { :type => "First Response SLA Violation", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::FIRST_RESPONSE_SLA_VIOLATION] },
      { :type => "Requester replies to Ticket", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::REPLIED_BY_REQUESTER] },
      { :type => "Resolution time SLA Violation", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::RESOLUTION_TIME_SLA_VIOLATION] },
      { :type => "Agent solves the Ticket", :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::TICKET_RESOLVED] },
      { :type => "Agent closes the Ticket", :requester => true, :agent => false, 
                  :obj => by_type[EmailNotification::TICKET_CLOSED] },
      { :type => "Requester reopens the Ticket", :requester => false, :agent => true, 
                  :obj => by_type[EmailNotification::TICKET_REOPENED] }]
  end

  def update      
      new_data = ActiveSupport::JSON.decode(params[:update][:notification_data])
      current_account.email_notifications.each do |n|
        n.update_attributes! new_data[n.id.to_s]
      end
      
      flash[:notice] = "Email notifications have been updated."
      redirect_back_or_default admin_email_notifications_url
  end
   
end
