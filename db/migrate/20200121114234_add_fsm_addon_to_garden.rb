class AddFsmAddonToGarden < ActiveRecord::Migration
  shard :none
  def up
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Garden'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Jan 17'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Jan 19'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Omni Jan 19'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name = 'Field Service Management') AND subscription_plan_id
        IN (SELECT id FROM subscription_plans WHERE name = 'Garden' or name = 'Garden Jan 17' or name = 'Garden Jan 19' or name = 'Garden Omni Jan 19')
    SQL
  end
end
