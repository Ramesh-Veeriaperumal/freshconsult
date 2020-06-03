class AddAddonsForLegacyPlansMigration < ActiveRecord::Migration
  shard :none
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Detect Thankyou Note Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Smart Filter Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Sla Management Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Customer slas Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Audit Log UI And Multi Product Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Article Versioning Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Whitelisted Ips Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Skill Based Round Robin Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Sandbox Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Hipaa Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Article Approval Workflow Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Agent Assist Lite Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Autofaq Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Botflow Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Detect Thankyou Note Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Detect Thankyou Note Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Smart Filter Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Smart Filter Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Blossom Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Smart Filter Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Sla Management Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Blossom Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Sla Management Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Customer slas Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Audit Log UI And Multi Product Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Audit Log UI And Multi Product Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Article Versioning Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Skill Based Round Robin Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Skill Based Round Robin Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Sandbox Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Sandbox Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Hipaa Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Hipaa Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Article Approval Workflow Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Article Approval Workflow Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Agent Assist Lite Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Agent Assist Lite Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Autofaq Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Autofaq Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Botflow Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Botflow Migration"))

    SQL
  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name IN ( "Detect Thankyou Note Migration", "Smart Filter Migration", "Sla Management Migration", "Customer slas Migration",
          "Audit Log UI And Multi Product Migration", "Article Versioning Migration", "Whitelisted Ips Migration", "Skill Based Round Robin Migration",
          "Sandbox Migration", "Hipaa Migration", "Article Approval Workflow Migration", "Agent Assist Lite Migration", "Autofaq Migration", "Botflow Migration"))
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ( "Detect Thankyou Note Migration", "Smart Filter Migration", "Sla Management Migration", "Customer slas Migration",
          "Audit Log UI And Multi Product Migration", "Article Versioning Migration", "Whitelisted Ips Migration", "Skill Based Round Robin Migration",
          "Sandbox Migration", "Hipaa Migration", "Article Approval Workflow Migration", "Agent Assist Lite Migration", "Autofaq Migration", "Botflow Migration")
    SQL
  end
end
