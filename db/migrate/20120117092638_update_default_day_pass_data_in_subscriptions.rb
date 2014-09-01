class UpdateDefaultDayPassDataInSubscriptions < ActiveRecord::Migration
  def self.up
    SubscriptionPlan.all.each do |sp|
      unless sp.free_agents.nil? || sp.day_pass_amount.nil? #okay for now..
        execute %(update subscriptions set free_agents=#{sp.free_agents}, 
          day_pass_amount=#{sp.day_pass_amount} where subscription_plan_id=#{sp.id} )
        end
      end
  end

  def self.down
  end
end
