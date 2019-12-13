class SystemNoteCcTemplateNotification < ActiveRecord::Migration
  shard :all
  
  def self.up
    Sharding.run_on_all_shards do
      Account.find_in_batches(:batch_size => 500) do |accounts|
        accounts.each do |account|
          begin
            p "For account ::: #{account.id}"
            account.make_current
            email_notification = {
              :notification_type => 26,     #EmailNotification::SYSTEM_NOTIFY_NOTE_CC
              :requester_notification => false, :agent_notification => true,
              :agent_template => '<p>Hi , <br/><br/> {{account_name}} added a note and wants you to have a look.</p><br> Ticket URL:<br> {{ticket.url}} <br><br> Subject: <br>{{ticket.subject}}<br><br> Requester: {{ticket.requester.name}} <br><br> Note Content: <br> {{comment.body}}',
              :agent_subject_template => 'Note Added - [#{{ticket.id}}] {{ticket.subject}}'
            }
            notification = account.email_notifications.build(email_notification)
            notification.save
          rescue Exception => e
            p e
          ensure
            Account.reset_current_account
          end
        end
      end
    end
  end


  def self.down
    Sharding.run_on_all_shards do
      Account.active_accounts.find_in_batches(:batch_size => 500) do |accounts|
        accounts.each do |account|
          EmailNotification.find_by_notification_type(EmailNotification::AUTOMATED_PRIVATE_NOTES).destroy
        end
      end
    end
  end
end