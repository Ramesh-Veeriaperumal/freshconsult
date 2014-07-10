class CleanupPlanIdInSubscriptions < ActiveRecord::Migration
	shard :shard_2
  
  def self.up
  	execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 12 where subscription_plan_id = 4;
		SQL
		execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 11 where subscription_plan_id = 3;
		SQL
		execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 10 where subscription_plan_id = 2;
		SQL
		execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 9 where subscription_plan_id = 1;
		SQL
  end

  def self.down
  	execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 1 where subscription_plan_id = 10;
		SQL
		execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 2 where subscription_plan_id = 11;
		SQL
		execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 3 where subscription_plan_id = 12;
		SQL
		execute <<-SQL
			UPDATE subscriptions SET subscription_plan_id = 4 where subscription_plan_id = 13;
		SQL
  end
end
