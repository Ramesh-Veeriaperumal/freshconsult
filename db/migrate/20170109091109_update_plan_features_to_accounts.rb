class UpdatePlanFeaturesToAccounts < ActiveRecord::Migration

  def migrate(direction)
    self.send(direction)
  end

  def up
    subscription_plan_ids = SubscriptionPlan.where("name like (?)","%sprout%").pluck(:id)
    Sharding.run_on_all_shards do
      Account.readonly(false).find_each(:joins => [:subscription], :conditions => [" subscriptions.state IN ('trial','free') or  subscriptions.subscription_plan_id IN (?) ", subscription_plan_ids], :batch_size => 200) do |account|
        account.add_feature(:branding)
      end
    end
  end

  def down
  end

end
