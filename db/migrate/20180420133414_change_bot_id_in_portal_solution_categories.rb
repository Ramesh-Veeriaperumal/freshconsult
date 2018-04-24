class ChangeBotIdInPortalSolutionCategories < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :portal_solution_categories, atomic_switch: true do |m|
      m.change_column :bot_id, "BIGINT(20) UNSIGNED DEFAULT NULL"
    end
  end

  def down
    Lhm.change_table :portal_solution_categories, atomic_switch: true do |m|
      m.change_column :bot_id, "INT(11) DEFAULT NULL"
    end
  end
end
