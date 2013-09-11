class Billing::ChangeSubscription
  extend Resque::AroundPerform
  
  @queue = "chargebeeQueue"

  def self.perform(args)
		account = Account.current
		result = Billing::Subscription.new.retrieve_subscription(account.id)

		update_plan_and_features(account.subscription, result.subscription.plan_id)
  end

  private
	  def self.update_plan_and_features(subscription, plan_code)
	  	plan = SubscriptionPlan.find_by_name(Billing::Subscription.helpkit_plan[plan_code])	  	
	  	return if subscription.subscription_plan_id == plan.id
	  	
	  	old_subscription = subscription
	  	subscription.update_attributes(plan_info(plan))
	  	SAAS::SubscriptionActions.new.change_plan(subscription.account, old_subscription)      
	  end

	  def self.plan_info(plan)
	  	{
	  		:subscription_plan => plan,
	  		:day_pass_amount => plan.day_pass_amount,
	  		:free_agents => plan.free_agents
	  	}
	  end

end