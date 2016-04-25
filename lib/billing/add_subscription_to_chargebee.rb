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
      subscription.save #to update resp. currency amount
      Subscription::AddAffiliateSubscription.perform(account)
    rescue Exception => e
      logger.info "#{e}"
      logger.info e.backtrace.join("\n")
      logger.info "something is wrong: #{e.message}"
      NewRelic::Agent.notice_error(e)   
      raise e 
    end
  end

  private
    def set_billing_site(subscription)
      currency = fetch_currency(subscription.account)
      subscription.set_billing_params(currency)      
      # subscription.send(:update_without_callbacks) #To avoid update amount callback
      subscription.sneaky_save
    end

    def fetch_currency(account)      
      return DEFAULT_CURRENCY if account.conversion_metric.nil?

      country = account.conversion_metric.country
      COUNTRY_MAPPING[country].nil? ? DEFAULT_CURRENCY : COUNTRY_MAPPING[country]  
    end

end