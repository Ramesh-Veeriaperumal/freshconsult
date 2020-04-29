class AddFreddyUltimateToAddons < ActiveRecord::Migration
  shard :none
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Freddy Ultimate", 75.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Freddy Ultimate")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Freddy Ultimate"))
    SQL
  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name IN ( "Freddy Ultimate"))
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Freddy Ultimate")
    SQL
  end
end
