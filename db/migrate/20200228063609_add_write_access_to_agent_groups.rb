class AddWriteAccessToAgentGroups < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :agent_groups, atomic_switch: true do |t|
      t.add_column :write_access, 'tinyint(1) DEFAULT 1'
    end
  end

  def down
    Lhm.change_table :agent_groups, atomic_switch: true do |t|
      t.remove_column :write_access, 'tinyint(1) DEFAULT 1'
    end
  end
end