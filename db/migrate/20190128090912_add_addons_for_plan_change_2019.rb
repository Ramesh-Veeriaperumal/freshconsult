class AddAddonsForPlanChange2019 < ActiveRecord::Migration
  shard :all
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
  	  INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Custom Slas 19", 10.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW()),
        ("Custom Ssl 19", 15.0, 1, "#{addon_types[:portal_quantity]}", NOW(), NOW()),
        ("Enterprise Reporting 19", 10.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW()),
        ("One Contact Multiple Companies 19", 69.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Whitelisted Ips 19", 20.0, 1, "#{addon_types[:agent_quantity]}", NOW(), NOW()),
        ("Unique External Id 19", 25.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Sandbox 19", 69.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Enterprise Reporting 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Sandbox 19"))
    SQL
  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name IN ( "Custom Slas 19", "Custom Ssl 19", "Enterprise Reporting 19", "One Contact Multiple Companies 19","Whitelisted Ips 19","Unique External Id 19","Sandbox 19"  ))
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Custom Slas 19", "Custom Ssl 19", "Enterprise Reporting 19","One Contact Multiple Companies 19","Whitelisted Ips 19","Unique External Id 19","Sandbox 19" )
    SQL
  end
end
