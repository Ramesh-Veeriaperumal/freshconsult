class AddFsmAddonToEstateAndForest < ActiveRecord::Migration
  shard :none
  
  def up
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Estate'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name = "Field Service Management") AND subscription_plan_id
        IN (SELECT id FROM subscription_plans WHERE name = 'Estate' or name = 'Forest')
    SQL
  end
end
