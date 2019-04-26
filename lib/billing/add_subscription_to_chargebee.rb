class Billing::AddSubscriptionToChargebee
  include Sidekiq::Worker
  include Subscription::Currencies::Constants
  
  sidekiq_options :queue => :chargebee_add_subscription, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    begin
      account = Account.current
      subscription = account.subscription
      set_billing_site(subscription)
      subscription.billing.create_subscription(account, {}, true)
      add_default_addons(subscription)
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

    def add_default_addons(subscription)
      addons_to_be_added = Subscription::Addon.addons_on_signup_list
      if addons_to_be_added.include?(Subscription::Addon::FSM_ADDON)
        subscription.additional_info = { :field_agent_limit => Subscription::DEFAULT_FIELD_AGENT_COUNT }
      end
      subscription.addons = Subscription::Addon.where('name in (?)', addons_to_be_added)
      features_to_add = subscription.addons.map { |addon| addon.features }.flatten
      NewPlanChangeWorker.new.perform({:features => [features_to_add], :action => "add"}) if features_to_add.size > 0
    end
end