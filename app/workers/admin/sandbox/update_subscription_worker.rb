class Admin::Sandbox::UpdateSubscriptionWorker < BaseWorker
  sidekiq_options queue: :update_sandbox_subscription, retry: 5, backtrace: true, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    sandbox_account_id = args[:sandbox_account_id]
    state = args[:state]
    Rails.logger.info("Starting Sandbox Subscription Update :: Account: #{account_id} :: Sandbox: #{sandbox_account_id} :: State: #{state}")
    Sharding.run_on_shard SANDBOX_SHARD_CONFIG do
      sandbox_account = Account.find(sandbox_account_id).make_current
      if state == Subscription::SUSPENDED
        suspend_sandbox_account(sandbox_account)
      elsif state == Subscription::TRIAL
        activate_sandbox_account(sandbox_account)
      end
    end
  rescue StandardError => error
    Rails.logger.error('UPDATE_SANDBOX_SUBSCRIPTION_ERROR :: ' \
      "Account: #{account_id} :: Sandbox Account: #{sandbox_account_id} \n" \
      "Error: #{error.message}\n#Backtrace: #{error.backtrace[0..30].inspect}")
    NewRelic::Agent.notice_error(error, description: "Sandbox update subscription error: #{account_id}")
  ensure
    Account.reset_current_account
  end

  private

    def activate_sandbox_account(sandbox_account)
      data = { trial_end: (sandbox_account.created_at + AccountConstants::SANDBOX_TRAIL_PERIOD.days).utc.to_i }
      result = Billing::ChargebeeWrapper.new.update_subscription(sandbox_account.id, data)
      raise 'Sandbox subscription failure: Move to Trial' unless result.subscription.status.eql?('in_trial')

      sandbox_subscription = sandbox_account.subscription
      sandbox_subscription.next_renewal_at = Time.at(result.subscription.trial_end).utc
      sandbox_subscription.state = Subscription::TRIAL
      sandbox_subscription.save
    end

    def suspend_sandbox_account(sandbox_account)
      response = Billing::Subscription.new.cancel_subscription(sandbox_account)
      raise 'Sandbox subscription failure: Move to Suspended' unless response

      sandbox_account.subscription.state = Subscription::SUSPENDED
      sandbox_account.subscription.save
    end
end
