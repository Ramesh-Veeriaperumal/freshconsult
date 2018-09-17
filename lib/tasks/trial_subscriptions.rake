namespace :trial_subscriptions do
  desc 'Look for all trail subscriptions which are active and then downgrade with conditions'
  task rollback_trail_subscriptions_data: :environment do
    time = Time.now.utc
    Sharding.run_on_all_slaves do
      Account.reset_current_account
      TrialSubscription.current_pod.ending_trials(time, 'active').find_in_batches(batch_size: 300) do |trail_subscriptions|
        trail_subscriptions.each do |trail_subscription|
          begin
            account = trail_subscription.account
            account.make_current
            trail_subscription.status = TrialSubscription::TRIAL_STATUSES[:inactive]
            Sharding.run_on_master { trail_subscription.save! }
            Rails.logger.info "Trial subscriptions : #{account.id} : Intializing downgrade"
          rescue e
            NewRelic::Agent.notice_error(e, description: "Trial subscriptions : #{account.try(:id)} : Error while initializing : trying to downgrade")
            Rails.logger.error "Trial subscriptions : #{account.try(:id)} : Error while initializing : trying to downgrade : #{e.inspect} #{e.backtrace.join("\n\t")}"
          ensure
            Account.reset_current_account
          end
        end
      end
    end
  end
end
