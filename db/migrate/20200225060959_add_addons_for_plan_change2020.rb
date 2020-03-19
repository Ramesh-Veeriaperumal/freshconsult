class AddAddonsForPlanChange2020 < ActiveRecord::Migration
  shard :all
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Custom Slas 20", 10.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW()),
        ("Custom Ssl 20", 15.0, 1, "#{addon_types[:portal_quantity]}", NOW(), NOW()),
        ("One Contact Multiple Companies 20", 69.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Whitelisted Ips 20", 25.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW()),
        ("Unique External Id 20", 25.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Fluffy Forest 20", 2000.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Fluffy Higher Plan1 20", 3500.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Fluffy Higher Plan2 20", 5500.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Fluffy Higher Plan3 20", 2000.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Fluffy Higher Plan4 20", 5500.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Field Service Management 20", 29.0, 1, "#{addon_types[:field_agent_quantity]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Forest 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Forest 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Forest 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Forest 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Blossom Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Field Service Management 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Field Service Management 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Field Service Management 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Field Service Management 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Field Service Management 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Field Service Management 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan1 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan2 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan3 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan3 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan4 20")),
        ((SELECT id FROM subscription_plans WHERE name = "Forest Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Fluffy Higher Plan4 20"))
    SQL
  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_plan_id
        IN (SELECT id FROM subscription_plans WHERE name IN ( "Garden Jan 20", "Estate Jan 20", "Estate Omni Jan 20", "Forest Jan 20", "Forest Omni Jan 20"))
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name IN ( "Field Service Management 20", "Custom Slas 20", "Custom Ssl 20", "One Contact Multiple Companies 20","Whitelisted Ips 20", "Unique External Id 19", "Fluffy Forest 20", "Fluffy Higher Plan1 20", "Fluffy Higher Plan2 20", "Fluffy Higher Plan3 20", "Fluffy Higher Plan4 20"  ))
    SQL
  end
end
