class AddGamificationEnabledFeature < ActiveRecord::Migration
  def self.up
    execute("insert into features(type,account_id,created_at,updated_at) select 'GamificationEnableFeature', account_id, now(), now() from subscriptions where (subscription_plan_id in (3,7))")
  end

  def self.down
    execute("delete from features inner join subscriptions on features.account_id = subscriptions.account_id where features.type = 'GamificationEnableFeature' and (subscriptions.subscription_plan_id in (3,7))")
  end
end
