class AddAutoRefreshFeature < ActiveRecord::Migration
  shard :none
  def self.up
    execute <<-SQL
      INSERT INTO features 
        (account_id, type, created_at, updated_at) 
        SELECT account_id, 'AutoRefreshFeature', now(), now() FROM subscriptions inner join subscription_plans 
        on subscriptions.subscription_plan_id = subscription_plans.id and subscriptions.amount > 0 and 
        subscriptions.state = "active" where subscription_plans.name in 
        ('Premium','Garden','Garden Classic','Estate','Estate Classic')
    SQL
  end

  def self.down
    execute("delete from features where type='AutoRefreshFeature'")
  end
end