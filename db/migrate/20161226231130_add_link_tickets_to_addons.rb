class AddLinkTicketsToAddons < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end
    
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ("Link Tickets", 5.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW())
    SQL
    
    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Blossom'), 
          (SELECT id FROM subscription_addons WHERE name = 'Link Tickets'))
    SQL
  end

  def down    
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ("Link Tickets")) 
    SQL
    
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Link Tickets" ) 
    SQL
  end
end