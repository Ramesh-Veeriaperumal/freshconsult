class AddFsmAddonToBlossom < ActiveRecord::Migration
  shard :none
  def up
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom Jan 17'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom Jan 19' AND classic = false),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name = 'Field Service Management') AND subscription_plan_id
        IN (SELECT id FROM subscription_plans WHERE name = 'Blossom' or name = 'Blossom Jan 17' or name = 'Blossom Jan 19')
    SQL
  end
end
