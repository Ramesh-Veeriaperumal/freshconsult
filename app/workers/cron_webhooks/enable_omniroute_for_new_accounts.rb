module CronWebhooks
  class EnableOmnirouteForNewAccounts < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_enable_omniroute_for_new_accounts, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        enable_omniroute_for_new_accounts
      end
    end

    def enable_omniroute_for_new_accounts
      eligibile_plans = [
        SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_19],
        SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_omni_jan_19],
        SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_19]
      ]
      plan_ids = SubscriptionPlan.where('name in (?)', eligibile_plans).pluck(:id)
      Sharding.run_on_all_slaves do
        Subscription.where("created_at > ? and state != 'suspended' and subscription_plan_id in (?)", 1.day.ago, plan_ids).find_in_batches(batch_size: 300) do |subscriptions|
          subscriptions.each do |subscription|
            begin
              account = subscription.account.make_current
              unless account.omni_channel_routing_enabled?
                Sharding.run_on_master do
                  account.set_feature(:omni_channel_routing)
                  account.set_feature(:lbrr_by_omniroute)
                  account.save!
                end
              end
            rescue Exception => e
              NewRelic::Agent.notice_error(e, description: "Enable Omniroute : #{account.try(:id)} : Error while adding omniroute features")
              Rails.logger.error "Enable Omniroute : #{account.try(:id)} : Error while adding omniroute features : #{e.inspect} #{e.backtrace.join("\n\t")}"
            ensure
              Account.reset_current_account
            end
          end
        end
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e, description: "Enable Omniroute : Error in enable_omniroute_for_new_accounts worker")
      Rails.logger.error "Enable Omniroute : Error in enable_omniroute_for_new_accounts : #{e.inspect} #{e.backtrace.join("\n\t")}"
    end
  end
end
