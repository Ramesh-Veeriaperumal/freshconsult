class AddPortalCssFeature < ActiveRecord::Migration
  def self.up
  	execute("INSERT INTO features(type,account_id,created_at,updated_at) (SELECT 'CssCustomizationFeature', account_id, now(), now() FROM subscriptions LEFT JOIN subscription_plans plans ON plans.id=subscriptions.subscription_plan_id WHERE plans.name IN ('Premium','Garden','Estate'))");
    execute("INSERT INTO features(type,account_id,created_at,updated_at) (SELECT 'LayoutCustomizationFeature', account_id, now(), now() FROM subscriptions LEFT JOIN subscription_plans plans ON plans.id=subscriptions.subscription_plan_id WHERE plans.name IN ('Estate'))");
  end

  def self.down
  	execute("DELETE FROM features WHERE features.type = 'CssCustomizationFeature' AND account_id IN (SELECT subscriptions.account_id FROM subscriptions INNER JOIN subscription_plans ON subscriptions.subscription_plan_id = subscription_plans.id WHERE subscription_plans.name IN ('Premium','Garden','Estate'))");
  	execute("DELETE FROM features WHERE features.type = 'LayoutCustomizationFeature' AND account_id IN (SELECT subscriptions.account_id FROM subscriptions INNER JOIN subscription_plans ON subscriptions.subscription_plan_id = subscription_plans.id WHERE subscription_plans.name IN ('Estate'))");
  end
end
