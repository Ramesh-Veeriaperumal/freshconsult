class Billing::AddToBilling
  extend Resque::AroundPerform
  include Subscription::Currencies::Constants
  
  @queue = "chargebeeQueue"

  def self.perform(args)
   account = Account.find(args[:account_id])
   subscription = account.subscription
   
   set_billing_site(subscription)
   subscription.billing.create_subscription(account)
   subscription.save #to update resp. currency amount
   Subscription::AddAffiliateSubscription.perform(account)
  end

  private
    def self.set_billing_site(subscription)
      currency = fetch_currency(subscription.account)
      subscription.set_billing_params(currency)      
      # subscription.send(:update_without_callbacks) #To avoid update amount callback
      subscription.sneaky_save
    end

    def self.fetch_currency(account)      
      return DEFAULT_CURRENCY if account.conversion_metric.nil?

      country = account.conversion_metric.country
      COUNTRY_MAPPING[country].nil? ? DEFAULT_CURRENCY : COUNTRY_MAPPING[country]  
    end

end