class AddCcNotificationTemplates < ActiveRecord::Migration
  shard :all
  
  def self.up
    Account.find_in_batches(:batch_size => 500) do |accounts|
      accounts.each do |account|
        begin
          p "For account ::: #{account.id}"
          account.make_current
          email_notifications = [{
            :notification_type => 21,     #EmailNotification::NOTIFY_COMMENT
            :requester_notification => false, :agent_notification => true,
            :agent_template => '<p>Hi , <br/><br/> {{comment.commenter.name}} added a note and wants you to have a look.</p><br> Ticket URL:<br> {{ticket.url}} <br><br> Subject: <br>{{ticket.subject}}<br><br> Requester: {{ticket.requester.name}} <br><br> Note Content: <br> {{comment.body}}',
            :agent_subject_template => 'Note Added - [#{{ticket.id}}] {{ticket.subject}}'
          },
          {
            :notification_type => 19,     #EmailNotification::NEW_TICKET_CC
            :requester_notification => true, :agent_notification => false,
            :requester_template => '<p>{{ticket.requester.name}} submitted a new ticket to {{ticket.portal_name}} and requested that we copy you</p><br><br>Ticket Description: <br>{{ticket.description}}',
            :requester_subject_template => 'Added as CC - [#{{ticket.id}}] {{ticket.subject}}'
          },
          {
            :notification_type => 20,     #EmailNotification::PUBLIC_NOTE_CC
            :requester_notification => true, :agent_notification => false,
            :requester_template => '<p>There is a new comment in the ticket submitted by {{ticket.requester.name}} to {{ticket.portal_name}}</p><br> Comment added by : {{comment.commenter.name}}<br><br>Comment Content: <br>{{comment.body}}',
            :requester_subject_template => 'New comment - [#{{ticket.id}}] {{ticket.subject}}'
          }]
          email_notifications.each do |email_notification|
            notification = account.email_notifications.build(email_notification)
            notification.save
          end
        rescue Exception => e
          p e
        ensure
          Account.reset_current_account
        end
      end
    end
  end


  def self.down
    Sharding.run_on_all_shards do
      EmailNotification.delete_all(["notification_type in (?)", [EmailNotification::NOTIFY_COMMENT, EmailNotification::NEW_TICKET_CC, EmailNotification::PUBLIC_NOTE_CC]])
    end
  end
end
