class AddForwardTemplateToEmailNotifications < ActiveRecord::Migration
  shard :all
  def self.up
    Sharding.run_on_all_shards do
      Account.active_accounts.find_in_batches(:batch_size => 100) do |accounts|
        accounts.each do |account|
          en = account.email_notifications.build(
            :notification_type => EmailNotification::DEFAULT_FORWARD_TEMPLATE, 
            :requester_notification => true, 
            :agent_notification => false,
            :requester_template => '<p>Please take a look at ticket <a href="{{ticket.url}}">#{{ticket.id}}</a> raised by {{ticket.requester.name}} ({{ticket.requester.email}}).</p>',
            :requester_subject_template => "{{ticket.subject}}")

          en.save
        end
      end
    end
  end

  def self.down
  end
end
