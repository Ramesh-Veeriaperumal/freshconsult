class AddAddonsToOmniChannelPlan2019 < ActiveRecord::Migration
  shard :none
  def self.up
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = "Garden Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Slas 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Custom Ssl 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Enterprise Reporting 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "One Contact Multiple Companies 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Whitelisted Ips 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Garden Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Unique External Id 19")),
        ((SELECT id FROM subscription_plans WHERE name = "Estate Omni Jan 19"),
          (SELECT id FROM subscription_addons WHERE name = "Sandbox 19"))
    SQL
  end

  def self.down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_plan_id
        IN (SELECT id FROM subscription_plans WHERE name IN ( "Garden Omni Jan 19", "Estate Omni Jan 19"))
    SQL
  end
end
