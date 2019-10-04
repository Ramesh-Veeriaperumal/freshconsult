class AddFluffyToAddons < ActiveRecord::Migration
  shard :all
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Fluffy Forest", 2000.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Fluffy Higher Plan1", 4000.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Fluffy Higher Plan2", 5500.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Fluffy Higher Plan3", 7000.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Fluffy Higher Plan4", 8000.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Forest"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan3"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan4"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan3"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan4"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Forest"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan3"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan4"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan3"))
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan4"))
    SQL
  end

  def self.down   
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name IN ( "Fluffy Forest", "Fluffy Higher Plan1", "Fluffy Higher Plan2", "Fluffy Higher Plan3", "Fluffy Higher Plan4" )
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Fluffy Forest", "Fluffy Higher Plan1", "Fluffy Higher Plan2", "Fluffy Higher Plan3", "Fluffy Higher Plan4" )
    SQL
  end
end
