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
    user.save(false)
  end

  def delete_user(user)
    user.deleted = true
    user.deleted_at = Time.zone.now
    user.save(false)
  end

  def paid_account?(account)
    return (account.subscription.amount > 0 && account.subscription.state == 'active')
  end

  def spam_url(account,user,table)
    shard_name = ShardMapping.lookup_with_account_id(account.id).shard_name
    type = table.split("_").last
    "admin.freshdesk.com/#{shard_name}/spam_watch/#{user.id}/#{type}"
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

  def core_spam_watcher
    begin
      puts "waiting for job..."
      list, element = $spam_watcher.blpop(SpamConstants::SPAM_WATCHER_BAN_KEY)
      queue, account_id, user_id = element.split(":")
      puts "#{list}, #{element}"
      return if WhitelistUser.find_by_account_id_and_user_id(account_id, user_id)
      # check if user is an agent or not
      Sharding.select_shard_of(account_id) do
        user = User.find_by_id(user_id)
        account = user.account
        account.make_current
        table_name = queue.split("sw_")[1]
        unless paid_account?(account)
          operation = "blocked"
          # block_spam_user(user)
        else
          operation = "deleted"
          # delete_user(user)
        end
        # deleted_users = account.all_users.find([user.id])
        deleted_users = [user]
        # SubscriptionNotifier.deliver_admin_spam_watcher(account, deleted_users,operation=="blocked")
        spam_alert(account,user,table_name,operation)
        # Notify admin about the blocked user
      end
    rescue Exception => e
      puts "#{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:description => "error occured in during processing spam_watcher_queue"})
    ensure
      Account.reset_current_account
    end
  end

end
