module CronWebhooks
  class TwitterCustomStream < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_twitter_custom_stream, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        enqueue_custom_stream_jobs
      end
    end

    private

      def enqueue_custom_stream_jobs
        if empty_queue?(Social::CustomTwitterWorker.get_sidekiq_options['queue'])
          Rails.logger.info "Twitter Queue is empty... queuing at #{Time.zone.now}"
          Sharding.run_on_all_slaves do
            Account.current_pod.active_accounts.each do |account|
              Account.reset_current_account
              account.make_current
              next if account.twitter_handles.empty?

              Social::CustomTwitterWorker.perform_async
            end
          end
        else
          Rails.logger.info "Custom Stream Worker is already running . skipping at #{Time.zone.now}"
        end
      end
  end
end
