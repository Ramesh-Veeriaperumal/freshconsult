module TrialSubscriptionHelper
  
  def create_trail_subscription(args)
    trial_subscription =  FactoryGirl.build(:trial_subscription, 
      trial_plan: args[:trial_plan] || SubscriptionPlan.last.name, 
      account_id: Account.current.id, actor_id: args[:user_id], 
      ends_at: (Time.now + 21.days).to_date,
      status: args[:status] || 0, from_plan: args[:from_subscription_plan] || 
      SubscriptionPlan.first.name)
    trial_subscription.save
    trial_subscription
  end
end 