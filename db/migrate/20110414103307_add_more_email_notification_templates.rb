class AddMoreEmailNotificationTemplates < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.email_notifications.build(
          :notification_type => EmailNotification::USER_ACTIVATION, 
          :account_id => account.id, 
          :requester_notification => true, 
          :agent_notification => true,
          :agent_template => 'Hi {{agent.name}},

Your {{helpdesk_name}} account has been created.

Click the url below to activate your account!

{{activation_url}}

If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.

Regards,
{{helpdesk_name}}',
          :requester_template => 'Hi {{contact.name}},

A new {{helpdesk_name}} account has been created for you.

Click the url below to activate your account and select a password!

{{activation_url}}

If the above URL does not work try copying and pasting it into your browser. If you continue to have problems, please feel free to contact us.

Regards,
{{helpdesk_name}}')

      account.email_notifications.build(
          :notification_type => EmailNotification::PASSWORD_RESET,
          :account_id => account.id, 
          :requester_notification => true, 
          :agent_notification => true,
          :agent_template => 'A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request, just click the link below:

{{password_reset_url}}

If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.',
          :requester_template => 'A request to reset your password has been made. If you did not make this request, simply ignore this email. If you did make this request, just click the link below:

{{password_reset_url}}

If the above URL does not work, try copying and pasting it into your browser. If you continue to have problem, please feel free to contact us.')

      account.email_notifications.build(
          :notification_type => EmailNotification::TICKET_UNATTENDED_IN_GROUP, 
          :account_id => account.id, 
          :requester_notification => false, 
          :agent_notification => true,
          :agent_template => 'Hi {{agent.name}},

A new ticket (#{{ticket.id}}) in group {{ticket.group.name}} is currently unassigned for more than {{ticket.group.assign_time_mins}} minutes.

Ticket Details: 

Subject - {{ticket.subject}}

Description  - {{ticket.description}}

This is an escalation email for the {{ticket.group.name}} group in {{helpdesk_name}}')
      
      account.email_notifications.build(
          :notification_type => EmailNotification::FIRST_RESPONSE_SLA_VIOLATION, 
          :account_id => account.id, 
          :requester_notification => false, 
          :agent_notification => true,
          :agent_template => 'Hi {{agent.name}},

There has been no response from the helpdesk for Ticket ID #{{ticket.id}}. The first response was due by {{ticket.fr_due_by_hrs}} today.

Ticket Details: 

Subject - {{ticket.subject}}

Requestor - {{ticket.requester.email}}

This is an escalation email from {{helpdesk_name}}')

      account.email_notifications.build(
          :notification_type => EmailNotification::RESOLUTION_TIME_SLA_VIOLATION, 
          :account_id => account.id, 
          :requester_notification => false, 
          :agent_notification => true,
          :agent_template => 'Hi {{agent.name}},

Ticket #{{ticket.id}} has not been resolved within the SLA time period. The ticket was due by {{ticket.due_by_hrs}} today.

Ticket Details: 

Subject - {{ticket.subject}}

Requestor - {{ticket.requester.email}}

This is an escalation email from {{helpdesk_name}}')
      
      account.save!
    end
  end

  def self.down
  end
end
