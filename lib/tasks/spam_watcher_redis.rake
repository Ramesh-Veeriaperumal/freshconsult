# # Block and delete the users if the user reaches the threashold twice
require 'spam_watcher/spam_watcher_redis_methods'
namespace :spam_watcher_redis do
  desc "This watcher continously watches if there is any anamoly in spam and blocks the users"
  task :global_spam_watcher => :environment do
    # skip if the user is whitelist
    loop do
      core_spam_watcher
    end
  end

  def core_spam_watcher
    begin
      puts "waiting for job..."
      list, element = $spam_watcher.blpop(SpamConstants::SPAM_WATCHER_BAN_KEY)
      queue, account_id, user_id = element.split(":")
      puts "#{list}, #{element}"
      table_name = queue.split("sw_")[1]
      Sharding.select_shard_of(account_id) do
        account, user = SpamWatcherRedisMethods.load_account_details(account_id, user_id)
        account.make_current
        unless user_id
          SpamWatcherRedisMethods.solution_articles(account)
          return
        end
        return if SpamWatcherRedisMethods.has_whitelisted_and_keyset?(account_id, user_id)
        SpamWatcherRedisMethods.check_spam(account, user, table_name)
        $spam_watcher.setex("spam_tickets_#{account_id}_#{user_id}",1.hour,"true")
      end
    rescue Exception => e
      puts "#{e.message}::::::#{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:description => "error occured in during processing spam_watcher_queue"})
    ensure
      Account.reset_current_account
    end
  end

end
