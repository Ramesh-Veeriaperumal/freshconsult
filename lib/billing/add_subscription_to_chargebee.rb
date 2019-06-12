class Billing::AddSubscriptionToChargebee
  include Sidekiq::Worker
  include Subscription::Currencies::Constants
  
  sidekiq_options :queue => :chargebee_add_subscription, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    begin
      account = Account.current
      subscription = account.subscription
      set_billing_site(subscription)
      subscription.billing.create_subscription(account)
      perform_fsm_subscriptions
      subscription.save #to update resp. currency amount
      EmailServiceProvider.perform_async
      Subscription::AddAffiliateSubscription.perform(account)
    rescue Exception => e
      logger.info "#{e}"
      logger.info e.backtrace.join("\n")
      logger.error "Error while adding new sign up subscription to Chargebee: #{e.message}"
      NewRelic::Agent.notice_error(e)   
      raise e 
    end
  end
  private
    def set_billing_site(subscription)
      currency = fetch_currency(subscription.account)
      subscription.set_billing_params(currency)      
      # subscription.safe_send(:update_without_callbacks) #To avoid update amount callback
      subscription.sneaky_save
    end

    def fetch_currency(account)      
      return DEFAULT_CURRENCY if account.conversion_metric.nil?

      country = account.conversion_metric.country
      COUNTRY_MAPPING[country].nil? ? DEFAULT_CURRENCY : COUNTRY_MAPPING[country]  
    end

    def perform_fsm_subscriptions
      return unless Account.current.admin_email.include?('+fsm')

      # We are not adding FSM addon during signup. Just calling the worker so that artifacts gets added.
      fsm_addon = Subscription::Addon.find_by_name(Subscription::Addon::FSM_ADDON)
      NewPlanChangeWorker.new.perform(features: fsm_addon.features, action: 'add')
    end
end