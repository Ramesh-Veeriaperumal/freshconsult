namespace :sitemap do
  
  desc "Generate sitemap"
  task :generate => :environment do
    include Redis::RedisKeys
    include Redis::PortalRedis
    
    Sharding.run_on_all_slaves do
      Account.reset_current_account
      @sitemap_enabled_accounts = []
      Rails.logger.info ":::::: SITEMAP RAKE: SITEMAP GENERATION STARTED: #{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S%:z")} ::::::"
      Account.active_accounts.find_in_batches(:batch_size => 300) do |accounts|
        accounts.each do |account|
          generate_sitemap(account)
        end
      end
      Rails.logger.info ":::::: SITEMAP RAKE: SITEMAP GENERATED FOR ACCOUNTS: #{@sitemap_enabled_accounts.join(",")} ::::::" unless @sitemap_enabled_accounts.empty?
      Rails.logger.info ":::::: SITEMAP RAKE: SITEMAP GENERATION ENDED: #{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S%:z")} ::::::"
    end
  end
end


def generate_sitemap(account)
  begin
    account.make_current
    key = SITEMAP_OUTDATED % { :account_id => account.id }
    if (account.features?(:sitemap) && portal_redis_key_exists?(key))
      Community::GenerateSitemap.perform_async(account.id)
      @sitemap_enabled_accounts << account.id
    end
  rescue Exception => e
    Rails.logger.info ":::::: GenerateSitemap: Sitemap exception for Account #{account.id}. Exception : #{e.inspect} ::::::"
    Rails.logger.info e.backtrace.join("\n")
    NewRelic::Agent.notice_error(e)
  ensure
    Account.reset_current_account
  end
end