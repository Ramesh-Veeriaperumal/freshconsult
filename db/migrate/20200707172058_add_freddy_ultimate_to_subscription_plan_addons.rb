class AddFreddyUltimateToSubscriptionPlanAddons < ActiveRecord::Migration
  shard :all
  def up
    execute <<-SQL
    INSERT INTO subscription_plan_addons
      (subscription_plan_id, subscription_addon_id) VALUES
      ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 17'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Ultimate')),
      ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Ultimate'))
    SQL
  end

  def down
    execute <<-SQL
    DELETE FROM subscription_plan_addons WHERE subscription_addon_id
      IN (SELECT id FROM subscription_addons WHERE name = 'Freddy Ultimate')
    SQL
  end
end
