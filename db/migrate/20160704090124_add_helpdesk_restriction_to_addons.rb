class AddHelpdeskRestrictionToAddons < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end
    
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ("Helpdesk Restriction", 49.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    
    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Sprout'), 
          (SELECT id FROM subscription_addons WHERE name = 'Helpdesk Restriction')),
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom'), 
          (SELECT id FROM subscription_addons WHERE name = 'Helpdesk Restriction')), 
        ((SELECT id FROM subscription_plans WHERE name = 'Garden'), 
          (SELECT id FROM subscription_addons WHERE name = 'Helpdesk Restriction'))
    SQL
  end

  def down    
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ("Helpdesk Restriction")) 
    SQL
    
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Helpdesk Restriction" ) 
    SQL
  end

end
