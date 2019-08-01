module CronWebhooks
  class FacebookDm < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_facebook_dm, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include CronWebhooks::Constants
    include Redis::RedisKeys
    include Redis::OthersRedis

    def perform(args)
      perform_block(args) do
        scheduler_facebook @args[:type]
      end
    end

    private

      def scheduler_facebook(account_type = 'paid')
        if account_type == 'paid'
          enqueue_premium_facebook
          enqueue_premium_facebook(2.minutes)
          enqueue_facebook 'paid'
        else
          enqueue_facebook 'trial'
        end
      end

      def enqueue_facebook(task_name)
        class_constant = FACEBOOK_TASKS[task_name][:class_name].constantize
        queue_name = class_constant.get_sidekiq_options['queue']
        Rails.logger.info "::::Queue Name::: #{queue_name}"
        if empty_queue?(queue_name)
          Sharding.run_on_all_slaves do
            Account.reset_current_account
            Social::FacebookPage.current_pod.safe_send(FACEBOOK_TASKS[task_name][:account_method]).each do |fb_page|
              Account.reset_current_account
              account = fb_page.account
              next unless account

              account.make_current
              next if !fb_page.valid_page? || check_if_premium_facebook_account?(account.id)

              class_constant.perform_async(fb_page_id: fb_page.id)
            end
          end
        else
          Rails.logger.info "Facebook Worker is already running . skipping at #{Time.zone.now}. Type #{task_name}"
        end
      end

      def enqueue_premium_facebook(delay = nil)
        premium_facebook_accounts.each do |account_id|
          Rails.logger.info "Enqueuing Premium Facebook Worker for account id #{account_id}"
          if delay.nil?
            Social::PremiumFacebookWorker.perform_async(account_id: account_id)
          else
            Social::PremiumFacebookWorker.perform_in(delay, account_id: account_id)
          end
        end
      end

      def premium_facebook_accounts
        get_all_members_in_a_redis_set(FACEBOOK_PREMIUM_ACCOUNTS)
      end

      def check_if_premium_facebook_account?(account_id)
        ismember?(FACEBOOK_PREMIUM_ACCOUNTS, account_id)
      end
  end
end
