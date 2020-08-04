class AddAddonsForOmniMigration < ActiveRecord::Migration
  shard :none
  def self.up
    addon_types = Subscription::Addon::ADDON_TYPES
    execute <<-SQL
      INSERT INTO subscription_addons
        (name, amount, renewal_period, addon_type, created_at, updated_at) VALUES
        ("Emailbot Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Custom Objects Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW()),
        ("Agent Articles Suggest Migration", 0.0, 1, "#{addon_types[:for_account]}", NOW(), NOW())
    SQL
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Detect Thankyou Note Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Smart Filter Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Sla Management Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Customer slas Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Audit Log UI And Multi Product Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Article Versioning Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Skill Based Round Robin Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Sandbox Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Hipaa Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Article Approval Workflow Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Agent Assist Lite Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Autofaq Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Botflow Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Emailbot Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Objects Migration")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20"),
          (SELECT id FROM subscription_addons WHERE name = "Agent Articles Suggest Migration"))
    SQL
  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_plan_id IN (SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 20") AND
      subscription_addon_id IN (SELECT id FROM subscription_addons WHERE name IN ("Emailbot Migration", "Custom Objects Migration", "Agent Articles Suggest Migration"))
    SQL
    execute <<-SQL
      DELETE FROM subscription_addons WHERE name IN ("Emailbot Migration", "Custom Objects Migration", "Agent Articles Suggest Migration")
    SQL
  end
end
