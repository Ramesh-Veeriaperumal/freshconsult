class AddSbrrAddon < ActiveRecord::Migration
  shard :shard_1
  def up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL 
    INSERT INTO subscription_addons 
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES 
        ('Skill Based Round Robin', 8.0, 1, #{addon_types[:agent_quantity]}, NOW(), NOW())
    SQL

    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Estate'), 
          (SELECT id FROM subscription_addons WHERE name = 'Skill Based Round Robin'))
    SQL

    execute <<-SQL
      INSERT INTO subscription_plan_addons 
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Estate Jan 17'), 
          (SELECT id FROM subscription_addons WHERE name = 'Skill Based Round Robin'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id 
        IN (SELECT id FROM subscription_addons WHERE name IN ('Skill Based Round Robin')) 
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( 'Skill Based Round Robin') 
    SQL
  end
end
