class AddFacebookPageTabFeature < ActiveRecord::Migration
	shard :none
  def self.up
  	execute(%(INSERT INTO features(type,account_id,created_at,updated_at) SELECT 
  		'FacebookPageTabFeature', account_id, now(), now() FROM subscriptions 
  		INNER JOIN subscription_plans plans ON plans.id=subscriptions.subscription_plan_id 
  		WHERE plans.name IN ('Estate', 'EstateClassic')))
  end

  def self.down
  end
end
