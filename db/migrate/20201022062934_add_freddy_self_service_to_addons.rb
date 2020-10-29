# frozen_string_literal: true

class AddFreddySelfServiceToAddons < ActiveRecord::Migration
  shard :none
  def up
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 17'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 19'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest Jan 20'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')),
        ((SELECT id FROM subscription_plans WHERE name = 'Forest Omni Jan 20'), (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name = 'Freddy Self Service')
    SQL
  end
end

AddFreddySelfServiceToAddons.new.up
