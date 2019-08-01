module CronWebhooks
  class BillingInfoUpdate < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_billing_info_update, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        enqueue_billing_info_udpate
      end
    end

    private

      def enqueue_billing_info_udpate
        Sharding.run_on_all_slaves do
          Account.preload(:account_additional_settings).paid_accounts.find_in_batches(batch_size: 300) do |accounts|
            accounts.each do |account|
              account.make_current
              next unless account.launched?(:allow_billing_info_update)

              begin
                additional_settings = account.account_additional_settings.additional_settings
                next if additional_settings && additional_settings[:paid_by_reseller]

                account.launch(:update_billing_info) unless account.launched?(:update_billing_info)
              ensure
                Account.reset_current_account
              end
            end
          end
        end
      end
  end
end
