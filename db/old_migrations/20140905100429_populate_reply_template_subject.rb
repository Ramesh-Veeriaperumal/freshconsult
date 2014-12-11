class PopulateReplyTemplateSubject < ActiveRecord::Migration

  shard :all

  def self.up
    ShardMapping.find_in_batches(:batch_size => 300) do |shards|
      failed_accounts = []
      dynamic_notifications = []
      shards.each do |shard|
        Account.reset_current_account
        begin
          Sharding.select_shard_of(shard.account_id) do
            account = Account.find(shard.account_id)
            account.make_current
            template = account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE)
            subject_prefix = account.features_included?(:id_less_tickets) ? "" : "[#{account.ticket_id_delimiter}{{ticket.id}}] "
            subject = "#{subject_prefix}{{ticket.subject}}"
            template.requester_subject_template = subject
            if template.save!
              puts "Success - EmailNotification for :: AccountId: #{account.id}"
              if account.features_included?(:dynamic_content)
                d_templates = template.dynamic_notification_templates
                d_templates.each do |d_template|
                  d_template.subject = subject
                  if d_template.save!
                    puts "Success DynamicNotificationTemplate for :: AccountId: #{account.id}"
                  else
                    dynamic_notifications << d_template.id
                  end
                end
              end
            else
              failed_accounts << account.id
            end
            Account.reset_current_account
          end
        rescue Exception => e
          puts "Unable to find the account::: #{shard.account_id} #{e}"
          next
        end
      end
      puts "Failed_accounts : #{failed_accounts.inspect}"
      puts "Dynamic_notifications : #{dynamic_notifications.inspect}"
    end
  end

end
