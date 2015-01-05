class AddChatRoutingFeature < ActiveRecord::Migration
	shard :all
  def self.up
  	execute(%(INSERT INTO features(type,account_id,created_at,updated_at) SELECT 
  		'ChatRoutingFeature', account_id, now(), now() FROM subscriptions 
  		INNER JOIN subscription_plans plans ON plans.id=subscriptions.subscription_plan_id 
  		WHERE plans.name IN ('Estate', 'Estate Classic', 'Forest')))
  end

  def self.down
  end
end