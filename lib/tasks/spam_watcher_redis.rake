# # Block and delete the users if the user reaches the threashold twice

namespace :spam_watcher_redis do
  desc "This watcher continously watches if there is any anamoly in spam and blocks the users"
  task :global_spam_watcher => :environment do
    # skip if the user is whitelist
    loop do
      core_spam_watcher
    end
  end


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
    return (account.subscription.amount > 0 && account.subscription.state == 'active')
  end

  def spam_url(account,user,table)
    shard_mapping = ShardMapping.lookup_with_account_id(account.id)
    type = table.split("_").last
    "freshopsadmin.freshdesk.com/#{shard_mapping.pod_info}/#{shard_mapping.shard_name}/spam_watch/#{user.id}/#{type}"
  end

  def spam_alert(account,user,table_name,operation)
    FreshdeskErrorsMailer.deliver_spam_watcher(
      {
        :subject          => "New Spam Watcher Abnormal load #{table_name}",
        :additional_info  => {
          :operation  => operation,
          :full_domain  => account.full_domain,
          :account_id  => account.id,
          :user_id => user.id,
          :admin_url => spam_url(account,user,table_name),
          :signature => "Spam Watcher"
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

  def core_spam_watcher
    begin
      puts "waiting for job..."
      list, element = $spam_watcher.blpop(SpamConstants::SPAM_WATCHER_BAN_KEY)
      queue, account_id, user_id = element.split(":")
      puts "#{list}, #{element}"
      unless user_id
        return if $spam_watcher.exists("spam_solutions_#{account_id}")
        Account.reset_current_account
        Sharding.select_shard_of(account_id) do
          account = Account.find(account_id)  
          account.make_current
          return if(paid_account?(account) || ((Time.now - 2.days).to_i - account.created_at.to_i) > 0)
          spam_blocked_alert(account)
          sub = account.subscription
          sub.state = "suspended"
          sub.save
        end
        $spam_watcher.setex("spam_solutions_#{account_id}",6.hours,"true")
        shard_map = ShardMapping.find(account_id)
        shard_map.status = ShardMapping::STATUS_CODE[:not_found]
        shard_map.save
        return 
      end
      return if WhitelistUser.find_by_account_id_and_user_id(account_id, user_id)
      # check if user is an agent or not
      return if $spam_watcher.exists("spam_tickets_#{account_id}_#{user_id}")
      Sharding.select_shard_of(account_id) do
        user = User.find_by_id(user_id)
        account = user.account
        account.make_current
        table_name = queue.split("sw_")[1]
        unless paid_account?(account)
          operation = "blocked"
          block_spam_user(user) if Rails.env.test?
        else
          operation = "deleted" 
          delete_user(user) if Rails.env.test?
        end
        # deleted_users = account.all_users.find([user.id])
        deleted_users = [user]
        # SubscriptionNotifier.deliver_admin_spam_watcher(account, deleted_users,operation=="blocked")
        spam_alert(account,user,table_name,operation)
        $spam_watcher.setex("spam_tickets_#{account_id}_#{user_id}",1.hour,"true")
        # Notify admin about the blocked user
      end
    rescue Exception => e
      puts "#{e.message}::::::#{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:description => "error occured in during processing spam_watcher_queue"})
    ensure
      Account.reset_current_account
    end
  end

end
