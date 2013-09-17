class Subscription::AddAffiliateSubscription
  extend Resque::AroundPerform

  @queue = "add_affiliate_subscription"

  class << self

    def perform(args)
      account = Account.current
      return unless affiliate_subscription?(account)
      
      affiliate = SubscriptionAffiliate.fetch_affiliate(account)
      begin
        add_affiliate(account, affiliate)
        add_discounts(account, affiliate)
      rescue Exception => error
        NewRelic::Agent.notice_error(error)
      end 
    end

    private
      def affiliate_subscription?(account)
        SubscriptionAffiliate.affiliate_subscription?(account)
      end

      def add_affiliate(account, affiliate)
        SubscriptionAffiliate.add_affiliate(account, affiliate.token)
      end

      def add_discounts(account, affiliate)
        affiliate.discounts.each do |discount|
          billing.add_discount(account, discount.code)
        end
      end

      def billing
        @billing ||= Billing::Subscription.new
      end
  end

end