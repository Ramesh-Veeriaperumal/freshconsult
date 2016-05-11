class SpamWatcherRedisMethods
  class << self
    def block_spam_user(user)
      user.blocked = true
      user.blocked_at = Time.zone.now + 10.years
      user.save(:validate => false)
    end

    def delete_user(user)
      user.deleted = true
      user.deleted_at = Time.zone.now
      user.save(:validate => false)
    end

    def paid_account?(account)
      (account.subscription.amount > 0 && account.subscription.state == 'active')
    end

    def spam_url(account,user,table)
      shard_mapping = ShardMapping.lookup_with_account_id(account.id)
      type = table.split("_").last
      "freshopsadmin.freshdesk.com/#{shard_mapping.pod_info}/#{shard_mapping.shard_name}/spam_watch/#{user.id}/#{type}"
    end

    def spam_alert(account,user,table_name,operation,subject,deleted_flag)
      FreshdeskErrorsMailer.deliver_spam_watcher(
        {
          :subject          => subject.present? ? subject : "New Spam Watcher Abnormal load #{table_name}",
          :additional_info  => {
            :operation  => operation,
            :full_domain  => account.full_domain,
            :account_id  => account.id,
            :user_id => user.id,
            :admin_url => spam_url(account,user,table_name),
            :signature => "Spam Watcher",
            :deleted_flag => deleted_flag
          }
        }
      )
    end

    def spam_blocked_alert(account)
      SubscriptionNotifier.deliver_admin_spam_watcher_blocked(account)
      FreshdeskErrorsMailer.deliver_spam_blocked_alert(
        {
          :subject          => "Blocked Account with id #{account.id} Due to heavy creation of solution articles",
          :additional_info  => {
            :account_id  => account.id,
            :full_domain  => account.full_domain,
            :signature => "Spam Watcher"
          }
        }
      )
    end

    def has_cmrr(account)
      account.subscription.cmrr > 5000
    end

    def has_whitelisted_and_keyset?(account_id, user_id)
      WhitelistUser.find_by_account_id_and_user_id(account_id, user_id) || $spam_watcher.exists("spam_tickets_#{account_id}_#{user_id}") 
    end

    def load_account_details(account_id, user_id)
      account = nil, user = nil
      account = Account.find_by_id(account_id)
      user = user_id ? User.find_by_id(user_id) : nil
      return account, user
    end

    def send_notification(account, user, table_name)
      operation = "auto blocked"
      subject = "Ignore the mail , user has been autoblocked"
      spam_alert(account,user,table_name,operation,subject,0)
      deleted_users = [user]
      #SubscriptionNotifier.deliver_admin_spam_watcher(account, deleted_users, 1)
    end

    def check_spam(account, user, table_name)
      if has_cmrr(account) 
        if !user.agent?
          operation = "deleted"
          # delete_user(user)
          spam_alert(account,user,table_name,operation,nil,0)
        else
          return
        end
      else
        if paid_account?(account) && user.agent?
          operation = "noticed spamming,"
          spam_alert(account,user,table_name,operation,nil,1)
        else
          #delete_user(user)
          #block_spam_user(user)
          send_notification(account,user,table_name)
        end
      end
    end

    def solution_articles(account)
      return if $spam_watcher.exists("spam_solutions_#{account.id}")
      return if(paid_account?(account) || ((Time.now - 2.days).to_i - account.created_at.to_i) > 0)
      spam_blocked_alert(account)
      sub = account.subscription
      sub.state = "suspended"
      sub.save
      $spam_watcher.setex("spam_solutions_#{account.id}",6.hours,"true")
      shard_map = ShardMapping.find(account.id)
      shard_map.status = ShardMapping::STATUS_CODE[:not_found]
      shard_map.save
      return 
    end
  end
end
