class Billing::AddToBilling
  QUEUE = "chargebeeQueue"
  
  class Record
    def self.perform(item_id)
      item = scoper.find(item_id)
      billing = Billing::Subscription.new
      perform_job(billing, item) #unless Rails.env.development?
    end
  end


  class CreateSubscription < Record
    @queue = QUEUE

    def self.scoper
      Account
    end

    def self.perform_job(billing, item)
      billing.create_subscription(item)
    end
  end


  class ActivateSubscription < Record
    @queue = QUEUE

    def self.scoper
      Subscription
    end

    def self.perform_job(billing, item)
      billing.activate_subscription(item)
    end
  end
  

  class UpdateAdmin < Record
    @queue = QUEUE

    def self.scoper
      AccountConfiguration
    end

    def self.perform_job(billing, item)
      billing.update_admin(item)
    end
  end


  class StoreCard < Record
    @queue = QUEUE

    def self.scoper
      Subscription
    end

    def self.perform_job(billing, item)
      billing.store_card(item)
    end
  end


  class AddDayPasses < Record
    @queue = QUEUE

    def self.scoper
      DayPassPurchase
    end

    def self.perform_job(billing, item)
      billing.buy_day_passes(item)
    end
  end


  class UpdateSubscription
    @queue = "chargebeeQueue"

    def self.perform(subscription_id, prorate)
     subscription = Subscription.find(subscription_id)
     Billing::Subscription.new.update_subscription(subscription, prorate)
    end 
  end

  
  class DeleteSubscription
    @queue = "chargebeeQueue"

    def self.perform(account_id)
     Billing::Subscription.new.delete_subscription(account_id)
    end 
  end

end