namespace :sitemap do
  
  desc "Generate sitemap"
  task :generate => :environment do
    include Redis::RedisKeys
    include Redis::PortalRedis
    
    Sharding.run_on_all_slaves do
      Account.reset_current_account
      Account.active_accounts.find_in_batches do |accounts|
        accounts.each do |account|
          generate_sitemap(account)
        end
      end
    end
  end
end


def generate_sitemap(account)
  begin
    account.make_current
    key = SITEMAP_OUTDATED % { :account_id => account.id }
    Community::GenerateSitemap.perform_async(account.id) if (account.features_included?(:sitemap) && portal_redis_key_exists?(key))
  rescue Exception => e
    puts e.inspect
    puts e.backtrace.join("\n")
    NewRelic::Agent.notice_error(e)
  ensure
    Account.reset_current_account
  end
end