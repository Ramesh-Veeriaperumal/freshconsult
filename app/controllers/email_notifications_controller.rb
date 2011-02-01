class EmailNotificationsController < ApplicationController
  def index
    e_notifications = current_account.email_notifications
    by_type = Hash[*e_notifications.map { |n| [n.notification_type, n] }.flatten]
    
    @notifications = [{ :type => "New Ticket Created", :requester => true, :agent => false, 
                                  :obj => by_type[EmailNotification::NEW_TICKET] },
                      { :type => "Ticket assigned to Group", :requester => false, :agent => true, 
                                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_GROUP] },
                      { :type => "Ticket assigned to Agent", :requester => false, :agent => true, 
                                  :obj => by_type[EmailNotification::TICKET_ASSIGNED_TO_AGENT] },
                      { :type => "Agent adds comment to Ticket", :requester => true, :agent => false, 
                                  :obj => by_type[EmailNotification::COMMENTED_BY_AGENT] },
                      { :type => "Requester adds comment to Ticket", :requester => false, :agent => true, 
                                  :obj => by_type[EmailNotification::COMMENTED_BY_REQUESTER] },
                      { :type => "Requester replies to Ticket", :requester => false, :agent => true, 
                                  :obj => by_type[EmailNotification::REPLIED_BY_REQUESTER] },
                      { :type => "Agent solves the Ticket", :requester => true, :agent => false, 
                                  :obj => by_type[EmailNotification::TICKET_RESOLVED] },
                      { :type => "Agent closes the Ticket", :requester => true, :agent => false, 
                                  :obj => by_type[EmailNotification::TICKET_CLOSED] },
                      { :type => "Requester reopens the Ticket", :requester => false, :agent => true, 
                                  :obj => by_type[EmailNotification::TICKET_REOPENED] }]
                      
    puts "@NOTIFICATIONS in EmailNotificationsController #{@notifications}"
  end

  def update
  end

end
