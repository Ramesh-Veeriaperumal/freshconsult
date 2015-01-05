class Billing::ChargebeeWrapper

	def initialize
    subscription = Account.current.subscription
    ChargeBee.configure(:site => subscription.currency_billing_site, 
                        :api_key => subscription.currency_billing_api_key)
  end

  #subscription
	def create_subscription(data)
		Rails.logger.debug ":::ChargeBee - Create Subscription - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Subscription.create(data)
	end

	def update_subscription(account_id, data)
		Rails.logger.debug ":::ChargeBee - Update Subscription - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Subscription.update(account_id, data)
	end

	def activate_subscription(account_id)
		ChargeBee::Subscription.update(account_id, :trial_end => 0)
	end

	def cancel_subscription(account_id)
		ChargeBee::Subscription.cancel(account_id)
	end

	def reactivate_subscription(account_id, data = {})
		ChargeBee::Subscription.reactivate(account_id, data)
	end

	def retrieve_subscription(account_id)
		ChargeBee::Subscription.retrieve(account_id)
	end

	#estimate
	def create_subscription_estimate(data)
		Rails.logger.debug ":::ChargeBee - Create Subscription Estimate - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Estimate.create_subscription(data)
	end

	def update_subscription_estimate(data)
		Rails.logger.debug ":::ChargeBee - Update Subscription Estimate - Params sent:::"
		Rails.logger.debug data.inspect
		ChargeBee::Estimate.update_subscription(data)
	end

	#card
	def add_card(account_id, data)
		ChargeBee::Card.update_card_for_customer(account_id, data)
	end

	def remove_credit_card(account_id)
    ChargeBee::Card.delete_card_for_customer(account_id)
  end

  #addons (daypass/freshfone)
	def update_non_recurring_addon(data)
		ChargeBee::Invoice.charge_addon(data)
	end

	def retrieve_addon(addon_name)		
		ChargeBee::Addon.retrieve(addon_name.to_s)
	end

	#other
	def update_customer(account_id, data)
		ChargeBee::Customer.update(account_id, data)
	end

	def add_discount(account_id, discount_code)
		ChargeBee::Subscription.update(account_id, :coupon => discount_code)
	end

	def retrieve_plan(billing_plan_name)
		ChargeBee::Plan.retrieve(billing_plan_name)
	end

	def retrieve_coupon(coupon_code)
		ChargeBee::Coupon.retrieve(URI.encode(coupon_code))
	end

end