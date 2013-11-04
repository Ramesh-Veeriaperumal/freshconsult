class Billing::AddToBilling
  extend Resque::AroundPerform
  
  @queue = "chargebeeQueue"

  def self.perform(args)
   account = Account.find(args[:account_id])
   Billing::Subscription.new.create_subscription(account)
   Subscription::AddAffiliateSubscription.perform(account)
  end

end