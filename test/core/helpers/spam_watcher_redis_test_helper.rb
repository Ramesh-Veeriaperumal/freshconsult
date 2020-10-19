# frozen_string_literal: true

module SpamWatcherRedisTestHelper
  def core_spam_watcher_rake(account, user)
    list, element = $spam_watcher.blpop(SpamConstants::SPAM_WATCHER_BAN_KEY)
    queue, account_id, user_id = element.split(':')
    table_name = queue.split('sw_')[1]

    return if account_id.to_i != account.id && user_id.to_i != user.id

    account, user = SpamWatcherRedisMethods.load_account_details(account_id, user_id)
    unless user_id
      SpamWatcherRedisMethods.solution_articles(account)
      return
    end
    return if SpamWatcherRedisMethods.has_whitelisted_and_keyset?(account_id, user_id)

    SpamWatcherRedisMethods.check_spam(account, user, table_name)
    $spam_watcher.setex("spam_tickets_#{account_id}_#{user_id}", 1.hour, 'true')
  rescue StandardError => e
    puts "#{e.message}::::::#{e.backtrace}"
    NewRelic::Agent.notice_error(e, description: 'error occured in during processing spam_watcher_queue')
  end
end
