class AddSandboxToAddons < ActiveRecord::Migration
  shard :all
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ("Sandbox", 69.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 17"), 
          (SELECT id FROM subscription_addons WHERE name = "Sandbox")) 
    SQL
  end

  def self.down    
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ( "Sandbox" )) 
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Sandbox" ) 
    SQL
  end
end
