class RecalculateAmountForSubscriptions < ActiveRecord::Migration
  def self.up
    Subscription.find(:all, :conditions => { :state => 'active' }).each do |subscription|
      s_plan = subscription.subscription_plan
      s_plan.discount = subscription.discount
      #subscription.total_amount
      
      r_period = subscription.renewal_period
      agent_amount = ((s_plan.amount * s_plan.fetch_discount(r_period)).round.to_f) * r_period
      subscription.amount = agent_amount * subscription.paid_agents
      
      subscription.save
    end
  end

  def self.down
  end
end
