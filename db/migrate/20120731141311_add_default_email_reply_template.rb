class AddDefaultEmailReplyTemplate < ActiveRecord::Migration
  def self.up
    execute("insert into email_notifications (account_id, requester_notification, agent_notification, requester_template, notification_type, created_at, updated_at)
      select id, true,false, '<p>Hi {{ticket.requester.name}},<br/><br/>Ticket: {{ticket.url}} <br/></p>',"+EmailNotification::DEFAULT_REPLY_TEMPLATE.to_s+", now(), now() from accounts")
  end

  def self.down
  	execute("delete from email_notifications where notification_type = "+EmailNotification::DEFAULT_REPLY_TEMPLATE.to_s)
  end
end
