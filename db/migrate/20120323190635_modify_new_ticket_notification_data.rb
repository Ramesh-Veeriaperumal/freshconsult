class ModifyNewTicketNotificationData < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      notification = account.email_notifications.find_by_notification_type(EmailNotification::NEW_TICKET)
      notification.agent_notification = false
      notification.agent_template = "Hi,

A new ticket has been created. 
You may view and respond to the ticket here {{ticket.url}}

Regards,
{{helpdesk_name}}"
      notification.agent_subject_template = "New Ticket has been created - [\#{{ticket.id}}] {{ticket.subject}}"
      notification.save
    end
  end

  def self.down
  end
end
