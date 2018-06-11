class AddUniqueExternalIdToSubscriptionAddons < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    send(direction)
  end

  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ('Unique External Id', 25.0, 1, #{addon_types[:for_account]}, NOW(), NOW())
    SQL

    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom'),
        (SELECT id FROM subscription_addons WHERE name = 'Unique External Id')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden'), 
        (SELECT id FROM subscription_addons WHERE name = 'Unique External Id')),
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom Jan 17'), 
        (SELECT id FROM subscription_addons WHERE name = 'Unique External Id')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Jan 17'), 
        (SELECT id FROM subscription_addons WHERE name = 'Unique External Id'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ('Unique External Id')) 
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ('Unique External Id') 
    SQL
  end
end

