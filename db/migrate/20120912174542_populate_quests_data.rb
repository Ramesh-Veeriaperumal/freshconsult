class PopulateQuestsData < ActiveRecord::Migration
  def self.up
    plan_ids = SubscriptionPlan.find(:all, :conditions => { 
      :name => ['Premium', 'Garden', 'Estate'] }).collect { |plan| plan.id }
      
    subscriptions = Subscription.find(:all, :conditions => { :subscription_plan_id => plan_ids }, 
      :include => :account)
      
    subscriptions.each do |subscription|
      if subscription.account
        puts "Populate Quest Data for #{subscription.account.id} - #{subscription.account.name}"
        subscription.account.quests.create(Gamification::Quests::Seed::DEFAULT_DATA)
      end
    end
  end

  def self.down
  end
end
