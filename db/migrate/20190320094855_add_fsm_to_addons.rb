class AddFsmToAddons < ActiveRecord::Migration
  shard :none

  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Field Service Management", 29.0, 1, "#{addon_types[:field_agent_quantity]}", NOW(), NOW())
    SQL

    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Jan 19'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Jan 17'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 19'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 17'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Omni Jan 19'),
          (SELECT id FROM subscription_addons WHERE name = 'Field Service Management'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name = "Field Service Management")
    SQL

    execute <<-SQL
      DELETE FROM subscription_addons WHERE name = "Field Service Management" 
    SQL
  end
end
