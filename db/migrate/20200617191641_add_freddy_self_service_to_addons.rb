class AddFreddySelfServiceToAddons < ActiveRecord::Migration
  shard :all
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ('Freddy Self Service', 100.0, 1, "#{addon_types[:on_off]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom Jan 17'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Jan 17'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Jan 17'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),

        ((SELECT id FROM subscription_plans WHERE name = 'Blossom Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Omni Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Omni Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),

        ((SELECT id FROM subscription_plans WHERE name = 'Blossom Jan 20'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Garden Jan 20'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Jan 20'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Omni Jan 20'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name = 'Freddy Self Service'
    SQL
  end
end
