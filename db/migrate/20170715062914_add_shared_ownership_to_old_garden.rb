class AddSharedOwnershipToOldGarden < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end

  def up
    execute <<-SQL
      INSERT INTO subscription_plan_addons
        (subscription_plan_id, subscription_addon_id) VALUES
        ((SELECT id FROM subscription_plans WHERE name = 'Garden'),
          (SELECT id FROM subscription_addons WHERE name = 'Shared Ownership'))
    SQL
  end

  def down
    execute <<-SQL
      DELETE FROM subscription_plan_addons WHERE subscription_addon_id
        IN (SELECT id FROM subscription_addons WHERE name IN ("Shared Ownership")) AND
        subscription_plan_id IN (SELECT id FROM subscription_plans WHERE name = 'Garden')
    SQL
  end
end
