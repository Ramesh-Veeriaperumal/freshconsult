module CronWebhooks
  class SitemapGenerate < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_sitemap_generate, retry: 0, dead: true, failures: :exhausted

    include Redis::RedisKeys
    include Redis::PortalRedis

    def perform(args)
      perform_block(args) do
        sitemap
      end
    end

    private

      def sitemap
        Sharding.run_on_all_slaves do
          Account.reset_current_account
          @sitemap_enabled_accounts = []
          Rails.logger.info ":::::: SITEMAP RAKE: SITEMAP GENERATION STARTED: #{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%:z')} ::::::"
          Account.active_accounts.find_in_batches(batch_size: 300) do |accounts|
            accounts.each do |account|
              generate_sitemap(account)
            end
          end
          Rails.logger.info ":::::: SITEMAP RAKE: SITEMAP GENERATED FOR ACCOUNTS: #{@sitemap_enabled_accounts.join(',')} ::::::" unless @sitemap_enabled_accounts.empty?
          Rails.logger.info ":::::: SITEMAP RAKE: SITEMAP GENERATION ENDED: #{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S%:z')} ::::::"
        end
      end

      def generate_sitemap(account)
        account.make_current
        key = format(SITEMAP_OUTDATED, account_id: account.id)
        if account.sitemap_enabled? && portal_redis_key_exists?(key)
          Community::GenerateSitemap.perform_async(account.id)
          @sitemap_enabled_accounts << account.id
        end
      rescue StandardError => e
        Rails.logger.info ":::::: GenerateSitemap: Sitemap exception for Account #{account.id}. Exception : #{e.inspect} ::::::"
        Rails.logger.info e.backtrace.join("\n")
        NewRelic::Agent.notice_error(e)
      ensure
        Account.reset_current_account
      end
  end
end
