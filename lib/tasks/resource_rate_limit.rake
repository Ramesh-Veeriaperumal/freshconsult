# Notify the admin when rate limit exceeds
namespace :resource_rate_limit do
  desc "This will notify admin when user exceeds limit"
  task :notify_admin => :environment do
  	loop do
  	  notify_admin
  	end
  end

  def spam_url(account,user,table)
    shard_name = ShardMapping.lookup_with_account_id(account.id).shard_name
    type = table.split("_").last
    "admin.freshdesk.com/#{shard_name}/spam_watch/#{user.id}/#{type}"
  end

  def rl_alert(account,user,queue)
    table = queue.split('RL_').last
    FreshdeskErrorsMailer.spam_watcher(
      {
        :subject          => "Resource Rate limit Abnormal load for #{table} resource!!!!",
        :additional_info  => {
          :full_domain  => account.full_domain,
          :account_id  => account.id,
          :user_id => user.id,
          :operation => 'detected',
          :admin_url => spam_url(account,user,table),
          :signature => "Resource Rate Limt"
        }
      }
    )
  end

  def notify_admin
  	begin
  	  puts "waiting for the job..."
      list, element = $spam_watcher.blpop(ResourceRateLimit::NOTIFY_KEYS)
      table, account_id, user_id = element.split(":")
      puts "#{list}, #{element}"

      Sharding.select_shard_of(account_id) do
        user = User.find_by_id(user_id)
        account = user.account
        account.make_current
        rl_alert(account,user,table)
      end

  	rescue Exception => e
  	  puts "#{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:description => "Error occured when notifying admin for resource rate limit"})
    ensure
      Account.reset_current_account
  	end	
  end
end