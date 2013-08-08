class AddMultipleBusinessHoursFeature < ActiveRecord::Migration
	shard :none
  def self.up
  	execute <<-SQL
      INSERT INTO features 
        (account_id, type, created_at, updated_at) 
        SELECT account_id, 'MultipleBusinessHoursFeature', now(), now() FROM subscriptions inner join subscription_plans 
        on subscriptions.subscription_plan_id = subscription_plans.id where subscription_plans.name in 
        ('Garden','Estate','Estate Classic')
    SQL
  end

  def self.down
  	execute("delete from features where type= 'MultipleBusinessHoursFeature'")
  end
end
