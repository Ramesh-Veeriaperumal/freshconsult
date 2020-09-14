class Billing::AddSubscriptionToChargebee
  include Sidekiq::Worker
  include Subscription::Currencies::Constants
  include Redis::OthersRedis
  
  sidekiq_options :queue => :chargebee_add_subscription, :retry => 0, :failures => :exhausted

  def perform
    begin
      account = Account.current
      subscription = account.subscription
      subscription.billing.create_subscription(account)
      perform_fsm_subscriptions
      subscription.save #to update resp. currency amount
      EmailServiceProvider.perform_async
      Subscription::AddAffiliateSubscription.perform(account)
      subscription.billing.activate_subscription(subscription, {}) if subscription.new_sprout?
    rescue Exception => e
      logger.info "#{e}"
      logger.info e.backtrace.join("\n")
      logger.error "Error while adding new sign up subscription to Chargebee: #{e.message}"
      NewRelic::Agent.notice_error(e)   
      raise e 
    end
  end
  private

    def perform_fsm_subscriptions
      return unless Account.current.admin_email.include?('+fsm') || redis_key_exists?(Redis::Keys::Others::FSM_GA_LAUNCHED)

      # We are not adding FSM addon during signup. Just calling the worker so that artifacts gets added.
      fsm_addon = Subscription::Addon.find_by_name(Subscription::Addon::FSM_ADDON)
      NewPlanChangeWorker.new.perform(features: fsm_addon.features, action: 'add')
    end
end
