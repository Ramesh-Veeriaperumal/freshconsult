class EnableAgentCollisionFeature < ActiveRecord::Migration
  def self.up
		execute <<-SQL
      INSERT INTO features 
        (account_id, type, created_at, updated_at) 
        SELECT account_id, 'AgentCollisionFeature', now(), now() FROM subscriptions
        where subscription_plan_id in (3,7) and account_id not in (select account_id from features where type = 'AgentCollisionFeature')
    SQL
  end

  def self.down
  end
end
