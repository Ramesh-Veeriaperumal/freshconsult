class AddDynamicSectionsToSubscriptionAddons < ActiveRecord::Migration
shard :shard_1
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL 
    INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ('Dynamic Sections', 10.0, 1, #{addon_types[:agent_quantity]}, NOW(), NOW())
    SQL

    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Sprout'), 
          (SELECT id FROM subscription_addons WHERE name = 'Dynamic Sections')), 
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom'), 
          (SELECT id FROM subscription_addons WHERE name = 'Dynamic Sections')), 
        ((SELECT id FROM subscription_plans WHERE name = 'Garden'), 
          (SELECT id FROM subscription_addons WHERE name = 'Dynamic Sections'))
    SQL

  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ('Dynamic Sections')) 
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( 'Dynamic Sections') 
    SQL

  end
end