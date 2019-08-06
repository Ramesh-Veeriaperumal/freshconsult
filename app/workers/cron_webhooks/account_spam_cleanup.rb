module CronWebhooks
  class AccountSpamCleanup < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_account_spam_cleanup, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args) do
        accounts_spam_cleanup_jobs @args[:type]
      end
    end

    private

      def accounts_spam_cleanup_jobs(account_type)
        Sharding.run_on_all_slaves do
          Account.current_pod.safe_send("#{account_type}_accounts").find_in_batches do |accounts|
            accounts.each do |account|
              account_id = account.id
              Rails.logger.info "#{account_type} enqueuing #{account_id} to Delete Spam Tickets Cleanup"
              AccountCleanup::DeleteSpamTicketsCleanup.perform_async(account_id: account_id)
            end
          end
        end
      end
  end
end
