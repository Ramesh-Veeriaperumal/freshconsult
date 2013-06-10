class AddCustomSslFeature < ActiveRecord::Migration
  def self.up
  	execute("insert into features(type,account_id,created_at,updated_at) select 'CustomSslFeature', account_id, now(), now() from subscriptions where (subscription_plan_id in (8,12))")
  end

  def self.down
  end
end
