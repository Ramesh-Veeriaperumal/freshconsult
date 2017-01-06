class AddSharedOwnershipToAddons < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end
    
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ("Shared Ownership", 6.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW())
    SQL
    
    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Estate'), 
          (SELECT id FROM subscription_addons WHERE name = 'Shared Ownership')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest'), 
          (SELECT id FROM subscription_addons WHERE name = 'Shared Ownership'))
    SQL
  end

  def down    
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ("Shared Ownership")) 
    SQL
    
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Shared Ownership" ) 
    SQL
  end

end
