module CronWebhooks
  class GoogleContactsSync < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_google_contacts_sync, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        google_contacts_sync
      end
    end

    private

      def google_contacts_sync
        Sharding.execute_on_all_shards do
          Rails.logger.info "Google contacts task initialized at #{Time.zone.now}"
          Integrations::GoogleContactsImporter.sync_google_contacts_for_all_accounts
          Rails.logger.info "Google contacts task finished at #{Time.zone.now}"
        end
      end
  end
end
