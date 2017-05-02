class AddSystemObserverEventsFeature < ActiveRecord::Migration
  shard :all

  VALID_PLANS = ["Blossom", "Garden", "Estate", "Forest", "Blossom Jan 17", "Garden Jan 17", "Estate Jan 17", "Forest Jan 17"]

  def migrate(direction)
    self.send(direction)
  end

  def up
    failed_accounts = []
    valid_plan_ids = SubscriptionPlan.where(:name => VALID_PLANS).pluck(:id)
    Account.preload(:subscription).find_each do |account|
      begin
        next if account.subscription.state == 'suspended' && valid_plan_ids.exclude?(account.subscription.subscription_plan_id)

        account.make_current
        account.add_feature(:system_observer_events) unless account.has_features? :system_observer_events

      rescue
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    puts "failed_accounts = #{failed_accounts.inspect}"
  end

  def down
    failed_accounts = []
    valid_plan_ids = SubscriptionPlan.where(:name => VALID_PLANS).pluck(:id)
    Account.preload(:subscription).find_each do |account|
      begin
        next if account.subscription.state == 'suspended' && valid_plan_ids.exclude?(account.subscription.subscription_plan_id)

        account.make_current
        account.revoke_feature(:system_observer_events) if account.has_features? :system_observer_events

      rescue
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    puts "failed_accounts = #{failed_accounts.inspect}"

  end

end
