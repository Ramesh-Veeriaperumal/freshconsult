class PopulateEmailNotificationsSubjectData < ActiveRecord::Migration
  def self.up
#    Account.all.each do |account|
#      account.email_notifications.each do |notification|
#        case notification.notification_type
#          when EmailNotification::USER_ACTIVATION
#            notification.requester_subject_template = "{{ticket.portal_name}} user activation"
#            notification.agent_subject_template = "{{ticket.portal_name}} user activation"
#          when EmailNotification::PASSWORD_RESET
#            notification.requester_subject_template = "{{ticket.portal_name}} password reset instructions"
#            notification.agent_subject_template = "{{ticket.portal_name}} password reset instructions"
#          when EmailNotification::NEW_TICKET
#            notification.requester_subject_template = "Ticket Received - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::TICKET_ASSIGNED_TO_GROUP
#            notification.agent_subject_template = "Assigned to Group - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::TICKET_UNATTENDED_IN_GROUP
#            notification.agent_subject_template = "Unattended Ticket - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::TICKET_ASSIGNED_TO_AGENT
#            notification.agent_subject_template = "Ticket Assigned - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::COMMENTED_BY_AGENT
#            notification.requester_subject_template = "Ticket Updated - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::REPLIED_BY_REQUESTER
#            notification.agent_subject_template = "New Reply Received - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::FIRST_RESPONSE_SLA_VIOLATION
#            notification.agent_subject_template = "Response time SLA violated - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::RESOLUTION_TIME_SLA_VIOLATION
#            notification.agent_subject_template = "Resolution time SLA violated - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::TICKET_RESOLVED
#            notification.requester_subject_template = "Ticket Resolved - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::TICKET_CLOSED
#            notification.requester_subject_template = "Ticket Closed - [\#{{ticket.id}}] {{ticket.subject}}"
#          when EmailNotification::TICKET_REOPENED
#            notification.agent_subject_template = "Ticket re-opened - [\#{{ticket.id}}] {{ticket.subject}}"
#          else
#        end
#        notification.save
#      end
#    end
  end
  

  def self.down
  end
end
